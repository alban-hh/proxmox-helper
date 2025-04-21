#!/usr/bin/env bash
APP="Nextcloud Exporter"
APP_SLUG="nextcloud-exporter"
RELEASE_REPO="xperimental/nextcloud-exporter"
BINARY_PATH="/usr/bin/nextcloud-exporter"
CONFIG_PATH="/etc/nextcloud-exporter.env"
SERVICE_NAME="nextcloud-exporter"
DEFAULT_PORT=9205

PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  require_debian_like
  get_local_ip
}

is_installed() {
  [[ -f "$BINARY_PATH" ]]
}

describe() {
  echo -e "${TAB}  - nextcloud-exporter .deb from the latest GitHub release"
  echo -e "${TAB}  - Service exposing metrics on port ${DEFAULT_PORT}"
}

deploy_release() {
  fetch_gh_release "nextcloud-exporter" "$RELEASE_REPO" "binary" "latest"
}

write_config() {
  local server token username="" password="" info_apps=true info_update=true skip_tls=false
  server="$(ask_required "Nextcloud URL (e.g. http://127.0.0.1:8080)")"
  token="$(ask_secret "Nextcloud auth token (empty to use username and password)")"
  if [[ -z "$token" ]]; then
    username="$(ask_required "Nextcloud username")"
    password="$(ask_secret "Nextcloud password")"
  fi
  confirm "Query app information?" || info_apps=false
  confirm "Query update information?" || info_update=false
  confirm "Skip TLS verification (self-signed certificate)?" && skip_tls=true
  cat >"$CONFIG_PATH" <<ENV
NEXTCLOUD_SERVER="${server}"
NEXTCLOUD_AUTH_TOKEN="${token}"
NEXTCLOUD_USERNAME="${username}"
NEXTCLOUD_PASSWORD="${password}"
NEXTCLOUD_INFO_UPDATE=${info_update}
NEXTCLOUD_INFO_APPS=${info_apps}
NEXTCLOUD_TLS_SKIP_VERIFY=${skip_tls}
NEXTCLOUD_LISTEN_ADDRESS=":${DEFAULT_PORT}"
ENV
  chmod 600 "$CONFIG_PATH"
}

create_service() {
  install_systemd_service "$SERVICE_NAME" "[Unit]
Description=Nextcloud Exporter
After=network.target

[Service]
User=root
EnvironmentFile=${CONFIG_PATH}
ExecStart=${BINARY_PATH}
Restart=always

[Install]
WantedBy=multi-user.target"
  enable_service "$SERVICE_NAME"
}

install() {
  deploy_release

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
  gh_release_available "nextcloud-exporter" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  stop_service "$SERVICE_NAME"
  deploy_release
  start_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  pkg_is_installed nextcloud-exporter && remove_packages nextcloud-exporter
  rm -f "$CONFIG_PATH" "$HOME/.nextcloud-exporter"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
