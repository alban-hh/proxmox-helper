#!/usr/bin/env bash
APP="CronMaster"
APP_SLUG="cronmaster"
RELEASE_REPO="fccview/cronmaster"
INSTALL_PATH="/opt/cronmaster"
CONFIG_PATH="${INSTALL_PATH}/.env"
CREDS_FILE="/root/cronmaster.creds"
SERVICE_NAME="cronmaster"
DEFAULT_PORT=3000

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd)" || PXH_ROOT=""
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  require_debian_like
  get_local_ip
}

is_installed() {
  [[ -d "$INSTALL_PATH" && -n "$(ls -A "$INSTALL_PATH" 2>/dev/null)" ]]
}

describe() {
  echo -e "${TAB}  - Node.js 22"
  echo -e "${TAB}  - CronMaster prebuilt release in ${INSTALL_PATH}"
}

deploy_release() {
  fetch_gh_release "cronmaster" "$RELEASE_REPO" "prebuild" "latest" "$INSTALL_PATH" "cronmaster_*_prebuild.tar.gz"
}

write_config() {
  local password="$1"
  cat >"$CONFIG_PATH" <<ENV
NODE_ENV=production
AUTH_PASSWORD=${password}
PORT=${DEFAULT_PORT}
HOSTNAME=0.0.0.0
NEXT_TELEMETRY_DISABLED=1
ENV
  chmod 600 "$CONFIG_PATH"
}

create_service() {
  install_systemd_service "$SERVICE_NAME" "[Unit]
Description=CronMaster
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_PATH}
EnvironmentFile=${CONFIG_PATH}
ExecStart=/usr/bin/node ${INSTALL_PATH}/server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"
  enable_service "$SERVICE_NAME"
}

install() {
  local password
  NODE_VERSION="22" setup_nodejs
  deploy_release
  password="$(random_alnum 16)"

  msg_info "Writing configuration"
  write_config "$password"
  msg_ok "Wrote ${CONFIG_PATH}"

  msg_info "Creating service"
  create_service
  msg_ok "Created service"

  printf 'CronMaster password: %s\nWeb UI: http://%s:%s\n' "$password" "$LOCAL_IP" "$DEFAULT_PORT" >"$CREDS_FILE"
  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
  msg_note "Password: ${password} (saved to ${CREDS_FILE})"
}

update() {
  gh_release_available "cronmaster" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  stop_service "$SERVICE_NAME"
  create_backup "$CONFIG_PATH" "${INSTALL_PATH}/scripts" "${INSTALL_PATH}/data" "${INSTALL_PATH}/snippets"
  CLEAN_INSTALL=1 deploy_release
  restore_backup
  start_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  rm -rf "$INSTALL_PATH"
  rm -f "$CREDS_FILE" "$HOME/.cronmaster"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
