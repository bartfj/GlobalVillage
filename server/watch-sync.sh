#!/usr/bin/env bash
# 检查本机 API 与公网隧道。进程不在就立刻拉起；公网连续失败再重启隧道。
# 由 launchd 每 2 分钟跑一次，也可以手动执行。
set -euo pipefail

UID_NUM="$(id -u)"
DOMAIN="gui/${UID_NUM}"
LOG="${HOME}/Library/Logs/globalvillage-sync-watch.log"
STATE="${HOME}/Library/Logs/globalvillage-sync-watch.state"
PORT="${PORT:-8787}"
PGPORT="${PGPORT:-5433}"
LOCAL_URL="http://127.0.0.1:${PORT}/v1/health"
PUBLIC_URL="${PUBLIC_URL:-https://api.vincent-tech.cn/v1/health}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

if [[ -f "${ROOT}/.env" ]]; then
  env_port="$(sed -n 's/^POSTGRES_PORT=//p' "${ROOT}/.env" | tr -d '\"[:space:]')"
  if [[ -n "${env_port}" ]]; then
    PGPORT="${env_port}"
  fi
fi

mkdir -p "${HOME}/Library/Logs"
touch "${STATE}"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >>"${LOG}"
}

state_get() {
  local key="$1"
  awk -F= -v k="${key}" '$1==k {print $2}' "${STATE}" | tail -n 1
}

state_set() {
  local key="$1"
  local value="$2"
  local tmp
  tmp="$(mktemp)"
  awk -F= -v k="${key}" -v v="${value}" '
    BEGIN { found=0 }
    $1==k { print k "=" v; found=1; next }
    { print }
    END { if (!found) print k "=" v }
  ' "${STATE}" >"${tmp}"
  mv "${tmp}" "${STATE}"
}

kick() {
  local label="$1"
  local now
  now="$(date +%s)"
  local last
  last="$(state_get "last_kick_${label}")"
  last="${last:-0}"
  if (( now - last < 120 )); then
    log "skip restart ${label}; last kick was $((now - last))s ago"
    return 0
  fi
  state_set "last_kick_${label}" "${now}"
  log "restart ${label}"
  launchctl kickstart -k "${DOMAIN}/${label}" >>"${LOG}" 2>&1 || log "kickstart failed ${label}"
}

local_ok() {
  local body
  body="$(curl -sf -m 5 "${LOCAL_URL}" || true)"
  [[ "${body}" == *global_village_server* ]]
}

public_ok() {
  local body attempt
  for attempt in 1 2; do
    body="$(curl -sf -m 12 "${PUBLIC_URL}" || true)"
    if [[ "${body}" == *global_village_server* ]]; then
      return 0
    fi
  done
  return 1
}

# 刚被 launchd 拉起时健康检查还没打开端口，这段时间不要再踢一次。
service_is_young() {
  local label="$1"
  local pid etime minutes
  pid="$(launchctl print "${DOMAIN}/${label}" 2>/dev/null | awk '/^\tpid = / { print $3; exit }')"
  if [[ -z "${pid}" ]]; then
    return 1
  fi
  etime="$(ps -o etime= -p "${pid}" 2>/dev/null | tr -d ' ')"
  if [[ -z "${etime}" || "${etime}" == *-* || "${etime}" == *:*:* ]]; then
    return 1
  fi
  minutes="${etime%%:*}"
  [[ "${minutes}" -lt 2 ]]
}

postgres_up() {
  nc -z -G 2 127.0.0.1 "${PGPORT}" >/dev/null 2>&1
}

cmd="${1:-check}"
if [[ "${cmd}" == "status" ]]; then
  if local_ok; then echo "local: up"; else echo "local: down"; fi
  if public_ok; then echo "public: up"; else echo "public: down"; fi
  exit 0
fi
if [[ "${cmd}" != "check" ]]; then
  echo "用法: $0 [check|status]" >&2
  exit 2
fi

if local_ok; then
  state_set local_fails 0
  log "local up"
else
  fails="$(state_get local_fails)"
  fails="${fails:-0}"
  fails="$((fails + 1))"
  state_set local_fails "${fails}"
  log "local down (${fails})"
  if service_is_young com.globalvillage.api; then
    log "api still starting; skip restart"
  elif postgres_up; then
    if [[ "${fails}" -ge 2 ]]; then
      kick com.globalvillage.api
    fi
  else
    log "postgres ${PGPORT} not listening; leave api alone"
  fi
fi

if ! pgrep -x cloudflared >/dev/null 2>&1 && ! pgrep -f '/cloudflared .*tunnel run' >/dev/null 2>&1; then
  log "cloudflared process missing"
  if service_is_young com.globalvillage.cloudflared; then
    log "tunnel still starting; skip restart"
  else
    kick com.globalvillage.cloudflared
    state_set public_fails 0
  fi
  exit 0
fi

if public_ok; then
  state_set public_fails 0
  log "public up"
  exit 0
fi

fails="$(state_get public_fails)"
fails="${fails:-0}"
fails="$((fails + 1))"
state_set public_fails "${fails}"
log "public down (${fails})"
if [[ "${fails}" -ge 3 ]]; then
  kick com.globalvillage.cloudflared
  state_set public_fails 0
fi
