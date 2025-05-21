#!/usr/bin/env bash
APP="Dokploy"
APP_SLUG="dokploy"
INSTALL_PATH="/etc/dokploy"
INSTALLER_URL="https://dokploy.com/install.sh"
DEFAULT_PORT=3000

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
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
  echo -e "${TAB}  - Dokploy via the upstream installer"
  echo -e "${TAB}  - Docker (if missing)"
  echo -e "${TAB}  - Redis"
}

install() {
  ensure_docker
  msg_info "Installing dependencies"
  if is_alpine; then
    ensure_packages git openssl
  else
    ensure_packages git openssl redis
  fi
  msg_ok "Installed dependencies"

  msg_warn "This runs the upstream installer from ${INSTALLER_URL}. Review it first if you care."
  confirm "Continue?" || {
    msg_warn "Installation cancelled."
    exit 0
  }

  msg_info "Installing ${APP}"
  $STD bash <(curl -fsSL "$INSTALLER_URL")
  msg_ok "Installed ${APP}"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
}

update() {
  msg_info "Updating ${APP}"
  $STD bash <(curl -fsSL "$INSTALLER_URL") update
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  if command -v docker &>/dev/null; then
    docker ps -aq | xargs -r docker rm -f &>/dev/null || true
    $STD docker network prune -f || true
  fi
  rm -rf "$INSTALL_PATH"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
