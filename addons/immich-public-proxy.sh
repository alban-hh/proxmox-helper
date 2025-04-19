#!/usr/bin/env bash
APP="Immich Public Proxy"
APP_SLUG="immich-public-proxy"
RELEASE_REPO="alangrainger/immich-public-proxy"
INSTALL_PATH="/opt/immich-proxy"
APP_PATH="${INSTALL_PATH}/app"
SERVICE_NAME="immich-proxy"
DEFAULT_PORT=3000

PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  require_debian_like
  get_local_ip
}

is_installed() {
  [[ -d "$INSTALL_PATH" && -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]
}

describe() {
  echo -e "${TAB}  - Node.js 22"
  echo -e "${TAB}  - Immich Public Proxy built from source in ${INSTALL_PATH}"
}

deploy_release() {
  fetch_gh_release "immichpublicproxy" "$RELEASE_REPO" "tarball" "latest" "$INSTALL_PATH"
}

build_app() {
  msg_info "Installing npm dependencies"
  (cd "$APP_PATH" && $STD npm ci)
  msg_ok "Installed npm dependencies"
  msg_info "Building ${APP}"
  (cd "$APP_PATH" && $STD npm run build)
  msg_ok "Built ${APP}"
}

valid_host() {
  local host="$1"
  [[ "$host" == "localhost" ]] && return 0
  [[ "$host" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && return 0
  [[ "$host" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]
}

ask_immich_host() {
  local host attempt=0
  while ((attempt < 3)); do
    host="$(ask "Local Immich IP or hostname" "")"
    if valid_host "$host"; then
      echo "$host"
      return 0
    fi
    msg_warn "That does not look like an IP or hostname."
    ((attempt++))
  done
  msg_warn "Falling back to ${LOCAL_IP}"
  echo "$LOCAL_IP"
}

create_service() {
  install_systemd_service "$SERVICE_NAME" "[Unit]
Description=Immich Public Proxy
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${APP_PATH}
EnvironmentFile=${APP_PATH}/.env
ExecStart=/usr/bin/node ${APP_PATH}/dist/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"
}

install() {
  local immich_host
  NODE_VERSION="22" setup_nodejs
  deploy_release
  build_app

  immich_host="$(ask_immich_host)"
  msg_info "Writing configuration"
  printf 'NODE_ENV=production\nIMMICH_URL=http://%s:2283\n' "$immich_host" >"${APP_PATH}/.env"
  chmod 600 "${APP_PATH}/.env"
  msg_ok "Wrote ${APP_PATH}/.env"

  msg_info "Creating service"
  create_service
  enable_service "$SERVICE_NAME"
  msg_ok "Created service"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
  msg_note "Extra options live in ${APP_PATH}/config.json"
}

update() {
  gh_release_available "immichpublicproxy" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  stop_service "$SERVICE_NAME"
  create_backup "${APP_PATH}/.env" "${APP_PATH}/config.json"
  NODE_VERSION="22" setup_nodejs
  CLEAN_INSTALL=1 deploy_release
  restore_backup
  build_app
  create_service
  start_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  rm -rf "$INSTALL_PATH"
  rm -f "$HOME/.immichpublicproxy"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
