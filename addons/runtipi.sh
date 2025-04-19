#!/usr/bin/env bash
APP="Runtipi"
APP_SLUG="runtipi"
INSTALL_PATH="/opt/runtipi"
INSTALLER_URL="https://raw.githubusercontent.com/runtipi/runtipi/master/scripts/install.sh"
DEFAULT_PORT=80

PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  require_debian_like
  confirm_not_pve_host
  get_local_ip
}

is_installed() {
  [[ -d "$INSTALL_PATH" ]]
}

describe() {
  echo -e "${TAB}  - Runtipi via the upstream installer"
  echo -e "${TAB}  - Docker (if missing)"
}

install() {
  ensure_docker
  msg_info "Installing dependencies"
  ensure_packages openssl
  msg_ok "Installed dependencies"

  msg_warn "This runs the upstream installer from ${INSTALLER_URL}. Review it first if you care."
  confirm "Continue?" || {
    msg_warn "Installation cancelled."
    exit 0
  }

  msg_info "Installing ${APP}"
  mkdir -p /etc/docker
  [[ -f /etc/docker/daemon.json ]] || echo '{ "log-driver": "journald" }' >/etc/docker/daemon.json
  curl -fsSL "$INSTALLER_URL" -o /opt/runtipi-install.sh
  chmod +x /opt/runtipi-install.sh
  (cd /opt && $STD ./runtipi-install.sh)
  rm -f /opt/runtipi-install.sh
  chmod 660 "${INSTALL_PATH}/state/settings.json" 2>/dev/null || true
  msg_ok "Installed ${APP}"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
}

update() {
  msg_info "Updating ${APP}"
  (cd "$INSTALL_PATH" && $STD ./runtipi-cli update latest)
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  if [[ -x "${INSTALL_PATH}/runtipi-cli" ]]; then
    (cd "$INSTALL_PATH" && $STD ./runtipi-cli stop) || true
  fi
  if command -v docker &>/dev/null; then
    (cd "$INSTALL_PATH" && $STD docker compose down --remove-orphans) || true
  fi
  rm -rf "$INSTALL_PATH"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
