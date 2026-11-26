#!/usr/bin/env bash
# 由 launchd 拉起的账号 API。数据库端口用 POSTGRES_PORT（当前是 5433）。
# .env 里的 DATABASE_URL 指向 5432，那是另一套库，不能拿来重启这台正在服务的 API。
set -euo pipefail

cd "$(dirname "$0")"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

PORT="${PORT:-8787}"
POSTGRES_PORT="${POSTGRES_PORT:-5433}"
POSTGRES_USER="${POSTGRES_USER:-gv}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-gvsecret}"
POSTGRES_DB="${POSTGRES_DB:-globalvillage}"
JWT_SECRET="${JWT_SECRET:-dev-local}"
DART="${DART_BIN:-/Users/vincent/sdk/dart-sdk/bin/dart}"

export PORT JWT_SECRET
export DATABASE_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=disable"
unset STORAGE || true
if [[ -n "${ADMIN_TOKEN:-}" ]]; then
  export ADMIN_TOKEN
fi

exec "${DART}" run bin/server.dart
