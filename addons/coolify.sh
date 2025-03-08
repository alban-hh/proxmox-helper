#!/usr/bin/env bash
APP="Coolify"
APP_SLUG="coolify"
INSTALL_PATH="/data/coolify"
INSTALLER_URL="https://cdn.coollabs.io/coolify/install.sh"
DEFAULT_PORT=8000

PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  confirm_not_pve_host
  get_local_ip
}

is_installed() {
  [[ -d "$INSTALL_PATH" ]]
}

describe() {
  echo -e "${TAB}  - Coolify via the upstream installer"
  echo -e "${TAB}  - Docker (if missing)"
}

run_installer() {
  $STD bash <(curl -fsSL "$INSTALLER_URL")
}

install() {
  ensure_docker
  msg_info "Installing dependencies"
  ensure_packages git openssl
  msg_ok "Installed dependencies"

  msg_warn "This runs the upstream installer from ${INSTALLER_URL}. Review it first if you care."
  confirm "Continue?" || {
    msg_warn "Installation cancelled."
    exit 0
  }

  msg_info "Installing ${APP}"
  run_installer
  msg_ok "Installed ${APP}"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
}

update() {
  msg_info "Updating ${APP}"
  run_installer
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  if command -v docker &>/dev/null; then
    (cd "${INSTALL_PATH}/source" 2>/dev/null && docker compose down --remove-orphans 2>/dev/null) || true
    docker ps -aq | xargs -r docker rm -f &>/dev/null || true
    $STD docker network prune -f || true
  fi
  rm -rf "$INSTALL_PATH"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
