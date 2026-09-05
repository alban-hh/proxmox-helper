#!/usr/bin/env bash
APP="SparkyFitness Garmin"
APP_SLUG="sparkyfitness-garmin"
RELEASE_REPO="CodeWithCJ/SparkyFitness"
INSTALL_PATH="/opt/sparkyfitness-garmin"
APP_PATH="${INSTALL_PATH}/SparkyFitnessGarmin"
CONFIG_DIR="/etc/sparkyfitness-garmin"
CONFIG_PATH="${CONFIG_DIR}/.env"
SERVICE_NAME="sparkyfitness-garmin"
DEFAULT_PORT=8000

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd)" || PXH_ROOT=""
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  require_debian_like
  get_local_ip
  if [[ ! -d /opt/sparkyfitness ]]; then
    msg_error "No SparkyFitness install found in /opt/sparkyfitness. Run this inside the SparkyFitness container."
    exit 238
  fi
}

is_installed() {
  [[ -d "$APP_PATH" ]]
}

describe() {
  echo -e "${TAB}  - Python 3.13 via uv"
  echo -e "${TAB}  - Garmin microservice in ${INSTALL_PATH}"
}

deploy_release() {
  fetch_gh_release "sparkyfitness-garmin" "$RELEASE_REPO" "tarball" "latest" "$INSTALL_PATH"
}

build_venv() {
  msg_info "Installing Python dependencies"
  (cd "$APP_PATH" && $STD uv venv --clear .venv && $STD uv pip install -r requirements.txt)
  msg_ok "Installed Python dependencies"
}

create_service() {
  install_systemd_service "$SERVICE_NAME" "[Unit]
Description=SparkyFitness Garmin microservice
After=network.target sparkyfitness-server.service
Requires=sparkyfitness-server.service

[Service]
Type=simple
WorkingDirectory=${APP_PATH}
EnvironmentFile=${CONFIG_PATH}
ExecStart=${APP_PATH}/.venv/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port ${DEFAULT_PORT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target"
  enable_service "$SERVICE_NAME"
}

install() {
  PYTHON_VERSION="3.13" setup_uv
  deploy_release
  build_venv

  msg_info "Writing configuration"
  mkdir -p "$CONFIG_DIR"
  cp "${INSTALL_PATH}/docker/.env.example" "$CONFIG_PATH"
  sed -i -e "s|^#\?GARMIN_MICROSERVICE_URL=.*|GARMIN_MICROSERVICE_URL=http://${LOCAL_IP}:${DEFAULT_PORT}|" "$CONFIG_PATH"
  chmod 600 "$CONFIG_PATH"
  msg_ok "Wrote ${CONFIG_PATH}"

  msg_info "Creating service"
  create_service
  msg_ok "Created service"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
  msg_warn "Set GARMIN_MICROSERVICE_URL=http://${LOCAL_IP}:${DEFAULT_PORT} in the SparkyFitness .env as well."
}

update() {
  gh_release_available "sparkyfitness-garmin" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  PYTHON_VERSION="3.13" setup_uv
  stop_service "$SERVICE_NAME"
  CLEAN_INSTALL=1 deploy_release
  build_venv
  start_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  rm -rf "$INSTALL_PATH" "$CONFIG_DIR"
  rm -f "$HOME/.sparkyfitness-garmin"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
