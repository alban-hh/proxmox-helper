#!/usr/bin/env bash
APP="CrowdSec"
APP_SLUG="crowdsec"

PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  require_debian_like
  confirm_not_pve_host
}

is_installed() {
  command -v cscli &>/dev/null
}

describe() {
  echo -e "${TAB}  - CrowdSec agent and local API"
  echo -e "${TAB}  - iptables firewall bouncer"
}

install() {
  msg_info "Setting up the ${APP} repository"
  ensure_packages curl gnupg
  $STD bash -c "curl -fsSL https://install.crowdsec.net | bash"
  msg_ok "Added repository"

  msg_info "Installing ${APP}"
  PXH_APT_UPDATED=""
  install_packages crowdsec
  msg_ok "Installed ${APP}"

  msg_info "Installing firewall bouncer"
  install_packages crowdsec-firewall-bouncer-iptables
  msg_ok "Installed firewall bouncer"

  echo
  msg_ok "${APP} is running. Check status with: cscli metrics"
}

update() {
  msg_info "Updating ${APP}"
  PXH_APT_UPDATED=""
  install_packages crowdsec crowdsec-firewall-bouncer-iptables
  $STD cscli hub update
  $STD cscli hub upgrade
  restart_service crowdsec
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_packages crowdsec crowdsec-firewall-bouncer-iptables
  rm -rf /etc/crowdsec /var/lib/crowdsec
  rm -f /etc/apt/sources.list.d/crowdsec*.list /etc/apt/sources.list.d/crowdsec*.sources
  msg_ok "Removed ${APP}"
}

run_addon "$@"
