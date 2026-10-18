#!/usr/bin/env bash
# 启动本机数据库 API，并用 Cloudflare Tunnel 把 8787 暴露到外网。
# 用法：
#   ./dev-tunnel.sh        前台跑隧道；Ctrl-C 停 API 与隧道（Postgres 保留）
#   ./dev-tunnel.sh stop   停 API、隧道，并停止 postgres 容器（数据卷保留）
#
# 未配置命名隧道时使用 trycloudflare.com，每次重启地址都会变，需要重新打包 APK。
# 命名隧道：先 cloudflared tunnel login，再建隧道并把配置写到 ~/.cloudflared/config.yml。
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
POSTGRES_PORT="${POSTGRES_PORT:-5433}"
HOST_DATABASE_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=disable"
API_LOG="${API_LOG:-/tmp/gv-auth.log}"
export PORT JWT_SECRET POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB POSTGRES_PORT
export DATABASE_URL="${HOST_DATABASE_URL}"

API_PID=""
CF_PID=""

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

wait_postgres() {
  local i
  for i in $(seq 1 40); do
    if docker compose exec -T postgres pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "Postgres 未在 40 秒内就绪" >&2
  exit 1
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
  exit 1
}

cleanup() {
  if [[ -n "${CF_PID}" ]]; then
    kill "${CF_PID}" 2>/dev/null || true
  fi
  if [[ -n "${API_PID}" ]]; then
    kill "${API_PID}" 2>/dev/null || true
  fi
}

start_api() {
  unset STORAGE
  export JWT_SECRET PORT
  export DATABASE_URL="${HOST_DATABASE_URL}"

  dart pub get
  echo "API → ${DATABASE_URL}"
  if [[ -n "${ADMIN_TOKEN:-}" ]]; then
    export ADMIN_TOKEN
    echo "管理后台: http://127.0.0.1:${PORT}/admin"
  fi
  dart run bin/server.dart >"${API_LOG}" 2>&1 &
  API_PID=$!
  wait_api
  echo "本机健康检查: curl -s http://127.0.0.1:${PORT}/v1/health"
}

run_tunnel() {
  if [[ ! -x "$(command -v cloudflared)" ]]; then
    echo "未找到 cloudflared。可执行: brew install cloudflared" >&2
    exit 1
  fi

  if [[ -f "${HOME}/.cloudflared/config.yml" ]]; then
    echo "使用命名隧道: ${HOME}/.cloudflared/config.yml"
    cloudflared tunnel run &
  else
    echo "未找到 ~/.cloudflared/config.yml，使用临时地址（重启会变，需重新打包 APK）"
    echo "外网基址形如: https://<随机名>.trycloudflare.com/v1"
    cloudflared tunnel --url "http://127.0.0.1:${PORT}" --no-autoupdate &
  fi

  CF_PID=$!
  wait "${CF_PID}"
}

stop_all() {
  free_api_port
  stop_tunnel
  docker compose stop postgres
  echo "已停止 API、隧道与 Postgres（数据卷保留）"
}

cmd="${1:-start}"
case "${cmd}" in
  start)
    trap cleanup EXIT INT TERM
    docker compose up -d postgres
    wait_postgres
    free_api_port
    start_api
    run_tunnel
    ;;
  stop)
    stop_all
    ;;
  *)
    echo "用法: $0 [start|stop]" >&2
    exit 1
    ;;
esac
