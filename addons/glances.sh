#!/usr/bin/env bash
APP="Glances"
APP_SLUG="glances"
INSTALL_PATH="/opt/glances"
VENV_PATH="${INSTALL_PATH}/.venv"
SERVICE_NAME="glances"
DEFAULT_PORT=61208

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd)" || PXH_ROOT=""
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  get_local_ip
}

is_installed() {
  [[ -d "$VENV_PATH" ]]
}

describe() {
  echo -e "${TAB}  - Python 3.12 via uv"
  echo -e "${TAB}  - Glances with the web UI in ${INSTALL_PATH}"
}

install_dependencies() {
  msg_info "Installing dependencies"
  if is_alpine; then
    ensure_packages gcc musl-dev linux-headers python3-dev python3 lm-sensors wireless-tools curl
  else
    ensure_packages gcc lm-sensors wireless-tools curl
  fi
  msg_ok "Installed dependencies"
}

pip_install() {
  (
    cd "$INSTALL_PATH" || exit 1
    . "${VENV_PATH}/bin/activate"
    $STD uv pip install --upgrade pip wheel setuptools
    $STD uv pip install --upgrade "glances[web]"
  )
}

create_service() {
  if is_alpine; then
    install_openrc_service "$SERVICE_NAME" "name=\"glances\"
description=\"Glances system monitor\"
command=\"${VENV_PATH}/bin/glances\"
command_args=\"-w\"
command_background=true
pidfile=\"/run/glances.pid\""
  else
    install_systemd_service "$SERVICE_NAME" "[Unit]
Description=Glances system monitor
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_PATH}
ExecStart=${VENV_PATH}/bin/glances -w
Restart=on-failure

[Install]
WantedBy=multi-user.target"
  fi
  enable_service "$SERVICE_NAME"
}

install() {
  install_dependencies
  PYTHON_VERSION="3.12" setup_uv

  msg_info "Installing ${APP}"
  mkdir -p "$INSTALL_PATH"
  (cd "$INSTALL_PATH" && $STD uv venv --clear)
  pip_install
  msg_ok "Installed ${APP}"

  msg_info "Creating service"
  create_service
  msg_ok "Created service"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
}

update() {
  msg_info "Updating ${APP}"
  pip_install
  restart_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  rm -rf "$INSTALL_PATH"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
