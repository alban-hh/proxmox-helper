#!/usr/bin/env bash
APP="Paperless-ngx Prometheus Exporter"
APP_SLUG="prometheus-paperless-ngx-exporter"
RELEASE_REPO="hansmi/prometheus-paperless-exporter"
BINARY_PATH="/usr/bin/prometheus-paperless-exporter"
CONFIG_DIR="/etc/prometheus-paperless-ngx-exporter"
CONFIG_PATH="${CONFIG_DIR}/config.env"
TOKEN_FILE="${CONFIG_DIR}/auth_token"
SERVICE_NAME="prometheus-paperless-ngx-exporter"
DEFAULT_PORT=8081

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
  echo -e "${TAB}  - prometheus-paperless-exporter .deb from the latest GitHub release"
  echo -e "${TAB}  - Service exposing metrics on port ${DEFAULT_PORT}"
}

deploy_release() {
  fetch_gh_release "prom-paperless-exp" "$RELEASE_REPO" "binary" "latest"
}

write_config() {
  local url token
  url="$(ask_required "Paperless-ngx URL (e.g. http://127.0.0.1:8000)")"
  token="$(ask_secret "Paperless-ngx API token")"
  mkdir -p "$CONFIG_DIR"
  printf 'PAPERLESS_URL="%s"\n' "$url" >"$CONFIG_PATH"
  printf '%s\n' "$token" >"$TOKEN_FILE"
  chmod 600 "$CONFIG_PATH" "$TOKEN_FILE"
}

create_service() {
  install_systemd_service "$SERVICE_NAME" "[Unit]
Description=Paperless-ngx Prometheus Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
EnvironmentFile=${CONFIG_PATH}
ExecStart=${BINARY_PATH} \\
  --paperless_url=\${PAPERLESS_URL} \\
  --paperless_auth_token_file=${TOKEN_FILE} \\
  --paperless_header 'Accept: application/json; version=9' \\
  --collectors=tag,correspondent,document_type,storage_path,task,log,group,user,status,statistics
Restart=always

[Install]
WantedBy=multi-user.target"
}

install() {
  deploy_release

  msg_info "Writing configuration"
  write_config
  msg_ok "Wrote ${CONFIG_PATH}"

  msg_info "Creating service"
  create_service
  enable_service "$SERVICE_NAME"
  msg_ok "Created service"

  ensure_update_script
  echo
  msg_ok "Metrics: ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}/metrics${CL}"
}

update() {
  if gh_release_available "prom-paperless-exp" "$RELEASE_REPO"; then
    msg_info "Updating ${APP}"
    stop_service "$SERVICE_NAME"
    deploy_release
  fi
  msg_info "Refreshing service definition"
  create_service
  restart_service "$SERVICE_NAME"
  msg_ok "Service is up to date"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  pkg_is_installed prometheus-paperless-exporter && remove_packages prometheus-paperless-exporter
  rm -rf "$CONFIG_DIR"
  rm -f "$HOME/.prom-paperless-exp"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
