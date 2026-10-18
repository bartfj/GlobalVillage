#!/usr/bin/env bash
# 本机数据库联调：只起 Postgres，Dart 在宿主机跑。
# 用法：
#   ./dev-db.sh          前台启动（Ctrl-C 只停 API，Postgres 与数据保留）
#   ./dev-db.sh stop     停 API，并停止 postgres 容器（不删数据卷）
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
# Homebrew 的 Postgres 常占住 127.0.0.1:5432。连这个地址会进本机库，而不是容器。
POSTGRES_PORT="${POSTGRES_PORT:-5433}"
# .env 里的主机名 postgres 只在 Compose 网络内有效；宿主机进程必须走本机端口。
HOST_DATABASE_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=disable"
# compose 即使只起 postgres 也会解析整个文件，包括 api 的 ${JWT_SECRET:?...}。
export PORT JWT_SECRET POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB POSTGRES_PORT
export DATABASE_URL="${HOST_DATABASE_URL}"

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

start_postgres() {
  docker compose up -d postgres
  wait_postgres
}

stop_all() {
  free_api_port
  docker compose stop postgres
  echo "已停止 API 与 Postgres（数据卷保留）"
}

run_api() {
  unset STORAGE
  export JWT_SECRET PORT
  export DATABASE_URL="${HOST_DATABASE_URL}"

  dart pub get
  echo "API → ${DATABASE_URL}"
  if [[ -n "${ADMIN_TOKEN:-}" ]]; then
    export ADMIN_TOKEN
    echo "管理后台: http://127.0.0.1:${PORT}/admin"
  fi
  echo "健康检查: curl -s http://127.0.0.1:${PORT}/v1/health"
  exec dart run bin/server.dart
}

cmd="${1:-start}"
case "${cmd}" in
  start)
    start_postgres
    free_api_port
    run_api
    ;;
  stop)
    stop_all
    ;;
  *)
    echo "用法: $0 [start|stop]" >&2
    exit 1
    ;;
esac
