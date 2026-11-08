#!/usr/bin/env bash
# 本机 Homebrew Postgres + Dart API + 命名 Cloudflare 隧道（不依赖 Docker）。
# 用法：
#   ./dev-local.sh          启动后跟日志（Ctrl-C 只停 tail，进程已 disown）
#   ./dev-local.sh daemon   只启动，不跟日志
#   ./dev-local.sh stop     停 API 与隧道
#   ./dev-local.sh status   探活
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

PORT="${PORT:-8787}"
JWT_SECRET="${JWT_SECRET:-dev-local}"
POSTGRES_USER="${POSTGRES_USER:-gv}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-gvsecret}"
POSTGRES_DB="${POSTGRES_DB:-globalvillage}"
# Homebrew Postgres 默认 5432（与 Docker 映射的 5433 区分）
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-5432}"
HOST_DATABASE_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${PGHOST}:${PGPORT}/${POSTGRES_DB}?sslmode=disable"
API_LOG="${API_LOG:-/tmp/gv-auth.log}"
TUNNEL_LOG="${TUNNEL_LOG:-/tmp/gv-tunnel.log}"

export PORT JWT_SECRET
export DATABASE_URL="${HOST_DATABASE_URL}"
unset STORAGE || true

ensure_db() {
  if ! pg_isready -h "${PGHOST}" -p "${PGPORT}" >/dev/null 2>&1; then
    echo "Postgres 未在 ${PGHOST}:${PGPORT} 就绪。请先启动 Homebrew postgresql。" >&2
    exit 1
  fi

  if ! PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${PGHOST}" -p "${PGPORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c 'SELECT 1' >/dev/null 2>&1; then
    echo "无法连接库 ${POSTGRES_DB}（用户 ${POSTGRES_USER}）。请先创建角色与库。" >&2
    exit 1
  fi
}

free_api_port() {
  local pids body
  pids="$(lsof -tiTCP:"${PORT}" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -z "${pids}" ]]; then
    return 0
  fi

  body="$(curl -sf "http://127.0.0.1:${PORT}/v1/health" || true)"
  if [[ "${body}" == *global_village_server* ]]; then
    echo "停止已有账号服务 (pid ${pids})"
    # shellcheck disable=SC2086
    kill ${pids} || true
    sleep 0.4
    return 0
  fi

  echo "端口 ${PORT} 已被其他进程占用: ${pids}" >&2
  exit 1
}

stop_tunnel() {
  local pids
  pids="$(pgrep -f "cloudflared tunnel" || true)"
  if [[ -n "${pids}" ]]; then
    echo "停止 Cloudflare Tunnel (pid ${pids})"
    # shellcheck disable=SC2086
    kill ${pids} || true
  fi
}

wait_api() {
  local i body
  for i in $(seq 1 40); do
    body="$(curl -sf "http://127.0.0.1:${PORT}/v1/health" || true)"
    if [[ "${body}" == *global_village_server* ]]; then
      return 0
    fi
    sleep 0.5
  done

  echo "API 未在 20 秒内就绪，日志: ${API_LOG}" >&2
  tail -30 "${API_LOG}" >&2 || true
  exit 1
}

cmd_status() {
  echo -n "local:  "
  curl -sf "http://127.0.0.1:${PORT}/v1/health" || echo "down"
  echo -n "public: "
  curl -sf -m 15 "https://api.vincent-tech.cn/v1/health" || echo "down"
  if [[ -n "${ADMIN_TOKEN:-}" ]]; then
    echo -n "admin:  "
    curl -sf -o /dev/null -w "%{http_code}\n" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      "https://api.vincent-tech.cn/admin/api/reports" || echo "down"
  fi
}

cmd_stop() {
  free_api_port
  stop_tunnel
  echo "已停止 API 与隧道（Postgres 保留）"
}

start_services() {
  ensure_db
  free_api_port
  stop_tunnel

  dart pub get
  : >"${API_LOG}"
  nohup env PORT="${PORT}" JWT_SECRET="${JWT_SECRET}" ADMIN_TOKEN="${ADMIN_TOKEN:-}" \
    DATABASE_URL="${DATABASE_URL}" \
    dart run bin/server.dart >>"${API_LOG}" 2>&1 &
  local api_pid=$!
  disown "${api_pid}" || true
  echo "API pid ${api_pid}  log ${API_LOG}"
  wait_api
  echo "在线账号服务已启动: http://127.0.0.1:${PORT}/v1"
  if [[ -n "${ADMIN_TOKEN:-}" ]]; then
    echo "管理后台: http://127.0.0.1:${PORT}/admin"
  fi

  : >"${TUNNEL_LOG}"
  nohup cloudflared tunnel run >>"${TUNNEL_LOG}" 2>&1 &
  local cf_pid=$!
  disown "${cf_pid}" || true
  echo "Tunnel pid ${cf_pid}  log ${TUNNEL_LOG}"
  echo "公网: https://api.vincent-tech.cn/v1 （命名隧道）"
}

cmd_start() {
  start_services
  echo "Ctrl-C 只停日志跟踪。停止服务请用 ./dev-local.sh stop"
  tail -f "${API_LOG}" "${TUNNEL_LOG}"
}

cmd_daemon() {
  start_services
  cmd_status
}

case "${1:-}" in
  stop) cmd_stop ;;
  status) cmd_status ;;
  daemon) cmd_daemon ;;
  "") cmd_start ;;
  *)
    echo "用法: $0 [daemon|stop|status]" >&2
    exit 2
    ;;
esac
