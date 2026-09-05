#!/usr/bin/env bash
APP="Actual Budget Prometheus Exporter"
APP_SLUG="actual-budget-prometheus-exporter"
RELEASE_REPO="sakowicz/actual-budget-prometheus-exporter"
INSTALL_PATH="/opt/actual-budget-prometheus-exporter"
CONFIG_PATH="/opt/actual-budget-prometheus-exporter.env"
SERVICE_NAME="actual-budget-prometheus-exporter"
DEFAULT_PORT=3001

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd)" || PXH_ROOT=""
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  require_debian_like
  get_local_ip
}

is_installed() {
  [[ -f "${INSTALL_PATH}/dist/app.js" ]]
}

describe() {
  echo -e "${TAB}  - Node.js 22"
  echo -e "${TAB}  - Exporter built from source in ${INSTALL_PATH}"
}

deploy_release() {
  fetch_gh_release "actual-budget-prometheus-exporter" "$RELEASE_REPO" "tarball" "latest" "$INSTALL_PATH"
}

build_app() {
  msg_info "Building ${APP}"
  (cd "$INSTALL_PATH" && $STD npm ci && $STD npm run build)
  msg_ok "Built ${APP}"
}

write_config() {
  local server_url password sync_id e2e_password port
  server_url="$(ask_required "Actual Budget server URL (e.g. http://127.0.0.1:5006)")"
  password="$(ask_secret "Actual Budget server password")"
  msg_note "The Sync ID is under Settings > Advanced settings in Actual."
  sync_id="$(ask_required "Budget Sync ID")"
  e2e_password="$(ask_secret "End-to-end encryption password (empty if disabled)")"
  port="$(ask "Metrics port" "$DEFAULT_PORT")"
  cat >"$CONFIG_PATH" <<ENV
ACTUAL_SERVER_URL="${server_url}"
ACTUAL_PASSWORD="${password}"
ACTUAL_BUDGET_ID_1="${sync_id}"
ACTUAL_E2E_PASSWORD_1="${e2e_password}"
PORT="${port}"
ENV
  chmod 600 "$CONFIG_PATH"
  METRICS_PORT="$port"
}

create_service() {
  install_systemd_service "$SERVICE_NAME" "[Unit]
Description=Actual Budget Prometheus Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
WorkingDirectory=${INSTALL_PATH}
EnvironmentFile=${CONFIG_PATH}
ExecStart=/usr/bin/node ${INSTALL_PATH}/dist/app.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"
  enable_service "$SERVICE_NAME"
}

install() {
  msg_info "Installing build dependencies"
  ensure_packages build-essential python3
  msg_ok "Installed build dependencies"
  NODE_VERSION="22" setup_nodejs
  deploy_release
  build_app

  msg_info "Writing configuration"
  write_config
  msg_ok "Wrote ${CONFIG_PATH}"

  msg_info "Creating service"
  create_service
  msg_ok "Created service"

  ensure_update_script
  echo
  msg_ok "Metrics: ${BL}http://${LOCAL_IP}:${METRICS_PORT}/metrics${CL}"
}

update() {
  gh_release_available "actual-budget-prometheus-exporter" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  stop_service "$SERVICE_NAME"
  CLEAN_INSTALL=1 deploy_release
  NODE_VERSION="22" setup_nodejs
  build_app
  start_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  rm -rf "$INSTALL_PATH"
  rm -f "$CONFIG_PATH" "$HOME/.actual-budget-prometheus-exporter"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
