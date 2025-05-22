#!/usr/bin/env bash
APP="qBittorrent Exporter"
APP_SLUG="qbittorrent-exporter"
RELEASE_REPO="martabal/qbittorrent-exporter"
INSTALL_PATH="/opt/qbittorrent-exporter"
BINARY_PATH="${INSTALL_PATH}/qbittorrent-exporter"
CONFIG_PATH="/opt/qbittorrent-exporter.env"
SERVICE_NAME="qbittorrent-exporter"
DEFAULT_PORT=8090

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  get_local_ip
}

is_installed() {
  [[ -f "$BINARY_PATH" ]]
}

describe() {
  echo -e "${TAB}  - Go toolchain"
  echo -e "${TAB}  - qbittorrent-exporter built from source in ${INSTALL_PATH}"
}

deploy_release() {
  fetch_gh_release "qbittorrent-exporter" "$RELEASE_REPO" "tarball" "latest" "$INSTALL_PATH"
}

build_app() {
  msg_info "Building ${APP}"
  (cd "$INSTALL_PATH" && $STD /usr/local/bin/go build -o ./qbittorrent-exporter)
  msg_ok "Built ${APP}"
}

write_config() {
  local base_url username password
  base_url="$(ask_required "qBittorrent URL (e.g. http://127.0.0.1:8080)")"
  username="$(ask "qBittorrent username" "admin")"
  password="$(ask_secret "qBittorrent password")"
  printf 'QBITTORRENT_BASE_URL="%s"
QBITTORRENT_USERNAME="%s"
QBITTORRENT_PASSWORD="%s"
' "$base_url" "$username" "$password" >"$CONFIG_PATH"
  chmod 600 "$CONFIG_PATH"
}

create_service() {
  if is_alpine; then
    install_openrc_service "$SERVICE_NAME" "name=\"qbittorrent-exporter\"
description=\"qBittorrent exporter for Prometheus\"
command=\"${BINARY_PATH}\"
command_background=true
directory=\"${INSTALL_PATH}\"
pidfile=\"/run/qbittorrent-exporter.pid\"
output_log=\"/var/log/qbittorrent-exporter.log\"
error_log=\"/var/log/qbittorrent-exporter.log\"

depend() {
  need net
  after firewall
}

start_pre() {
  if [ -f \"${CONFIG_PATH}\" ]; then
    export \$(grep -v '^#' ${CONFIG_PATH} | xargs)
  fi
}"
  else
    install_systemd_service "$SERVICE_NAME" "[Unit]
Description=qBittorrent exporter for Prometheus
After=network.target

[Service]
User=root
WorkingDirectory=${INSTALL_PATH}
EnvironmentFile=${CONFIG_PATH}
ExecStart=${BINARY_PATH}
Restart=always

[Install]
WantedBy=multi-user.target"
  fi
  enable_service "$SERVICE_NAME"
}

install() {
  deploy_release
  setup_go
  build_app

  msg_info "Writing configuration"
  write_config
  msg_ok "Wrote ${CONFIG_PATH}"

  msg_info "Creating service"
  create_service
  msg_ok "Created service"

  ensure_update_script
  echo
  msg_ok "Metrics: ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}/metrics${CL}"
}

update() {
  gh_release_available "qbittorrent-exporter" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  stop_service "$SERVICE_NAME"
  deploy_release
  setup_go
  build_app
  start_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  rm -rf "$INSTALL_PATH"
  rm -f "$CONFIG_PATH" "$HOME/.qbittorrent-exporter"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
