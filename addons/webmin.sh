#!/usr/bin/env bash
APP="Webmin"
APP_SLUG="webmin"
RELEASE_REPO="webmin/webmin"
DEFAULT_PORT=10000

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  require_debian_like
  get_local_ip
}

is_installed() {
  [[ -d /usr/share/webmin ]]
}

describe() {
  echo -e "${TAB}  - Perl prerequisites"
  echo -e "${TAB}  - Webmin from the latest GitHub release"
}

deploy_release() {
  fetch_gh_release "webmin" "$RELEASE_REPO" "binary" "latest" "/opt/webmin" "webmin_*_all.deb"
}

install() {
  msg_info "Installing prerequisites"
  ensure_packages libnet-ssleay-perl libauthen-pam-perl libio-pty-perl unzip shared-mime-info curl
  msg_ok "Installed prerequisites"

  deploy_release

  msg_info "Setting the Webmin root password to match the system root"
  /usr/share/webmin/changepass.pl /etc/webmin root root &>/dev/null || true
  msg_ok "Password configured"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}https://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
  msg_warn "Change the Webmin root password after first login."
}

update() {
  gh_release_available "webmin" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  deploy_release
  restart_service webmin
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_packages webmin
  rm -rf /etc/webmin /var/webmin "$HOME/.webmin"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
