#!/usr/bin/env bash
# 把 API、Cloudflare 隧道和每 2 分钟的探活交给当前用户的 launchd。
# 用法：
#   ./install-watch.sh            安装并立刻接管（会换下已有的 API 与隧道进程）
#   ./install-watch.sh uninstall  卸下托管，不停止 Postgres
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
UID_NUM="$(id -u)"
DOMAIN="gui/${UID_NUM}"
AGENTS="${HOME}/Library/LaunchAgents"
LOG_DIR="${HOME}/Library/Logs"
DART="${DART_BIN:-/Users/vincent/sdk/dart-sdk/bin/dart}"
CLOUDFLARED="${CLOUDFLARED_BIN:-/Users/vincent/bin/cloudflared}"

LABEL_API="com.globalvillage.api"
LABEL_TUNNEL="com.globalvillage.cloudflared"
LABEL_WATCH="com.globalvillage.sync-watch"

bootout() {
  launchctl bootout "${DOMAIN}/$1" >/dev/null 2>&1 || true
}

write_plist() {
  local dest="$1"
  cat >"${dest}"
  chmod 644 "${dest}"
}

stop_listeners() {
  local port="$1"
  local pids
  pids="$(lsof -tiTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -z "${pids}" ]]; then
    return 0
  fi
  # shellcheck disable=SC2086
  kill ${pids} || true
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if ! lsof -tiTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.3
  done
  echo "端口 ${port} 仍被占用" >&2
  exit 1
}

uninstall() {
  bootout "${LABEL_WATCH}"
  bootout "${LABEL_API}"
  bootout "${LABEL_TUNNEL}"
  rm -f \
    "${AGENTS}/${LABEL_API}.plist" \
    "${AGENTS}/${LABEL_TUNNEL}.plist" \
    "${AGENTS}/${LABEL_WATCH}.plist"
  echo "已卸下 launchd 托管。API 与隧道不会再自动拉起。"
}

if [[ "${1:-}" == "uninstall" ]]; then
  uninstall
  exit 0
fi
if [[ -n "${1:-}" ]]; then
  echo "用法: $0 [uninstall]" >&2
  exit 2
fi

if [[ ! -x "${DART}" ]]; then
  echo "找不到 dart: ${DART}" >&2
  exit 1
fi
if [[ ! -x "${CLOUDFLARED}" ]]; then
  echo "找不到 cloudflared: ${CLOUDFLARED}" >&2
  exit 1
fi

chmod 755 "${ROOT}/run-api.sh" "${ROOT}/watch-sync.sh"
mkdir -p "${AGENTS}" "${LOG_DIR}"

write_plist "${AGENTS}/${LABEL_API}.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL_API}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${ROOT}/run-api.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${ROOT}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>10</integer>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/globalvillage-api.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/globalvillage-api.log</string>
</dict>
</plist>
EOF

write_plist "${AGENTS}/${LABEL_TUNNEL}.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL_TUNNEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${CLOUDFLARED}</string>
    <string>--no-autoupdate</string>
    <string>tunnel</string>
    <string>run</string>
    <string>--protocol</string>
    <string>http2</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>10</integer>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/globalvillage-cloudflared.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/globalvillage-cloudflared.log</string>
</dict>
</plist>
EOF

write_plist "${AGENTS}/${LABEL_WATCH}.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL_WATCH}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${ROOT}/watch-sync.sh</string>
    <string>check</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>120</integer>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/globalvillage-sync-watch.launchd.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/globalvillage-sync-watch.launchd.log</string>
</dict>
</plist>
EOF

bootout "${LABEL_WATCH}"
bootout "${LABEL_API}"
bootout "${LABEL_TUNNEL}"

if pgrep -f '/cloudflared .*tunnel run' >/dev/null 2>&1; then
  pkill -f '/cloudflared .*tunnel run' || true
  sleep 0.5
fi
stop_listeners 8787

launchctl bootstrap "${DOMAIN}" "${AGENTS}/${LABEL_TUNNEL}.plist"
launchctl bootstrap "${DOMAIN}" "${AGENTS}/${LABEL_API}.plist"
launchctl bootstrap "${DOMAIN}" "${AGENTS}/${LABEL_WATCH}.plist"

local_up=""
for _ in $(seq 1 40); do
  body="$(curl -sf -m 2 "http://127.0.0.1:8787/v1/health" || true)"
  if [[ "${body}" == *global_village_server* ]]; then
    local_up="yes"
    break
  fi
  sleep 0.5
done

if [[ -z "${local_up}" ]]; then
  echo "API 未在 10 秒内就绪。日志: ${LOG_DIR}/globalvillage-api.log" >&2
  tail -n 30 "${LOG_DIR}/globalvillage-api.log" >&2 || true
  exit 1
fi

echo "已交给 launchd。"
echo "本机: $(curl -sf -m 5 http://127.0.0.1:8787/v1/health)"
echo "日志: ${LOG_DIR}/globalvillage-sync-watch.log"
echo "卸下: ${ROOT}/install-watch.sh uninstall"
