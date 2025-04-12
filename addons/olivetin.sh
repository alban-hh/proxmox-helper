#!/usr/bin/env bash
APP="OliveTin"
APP_SLUG="olivetin"
RELEASE_REPO="OliveTin/OliveTin"
SERVICE_NAME="OliveTin"
DEFAULT_PORT=1337

PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  require_debian_like
  get_local_ip
}

is_installed() {
  command -v olivetin &>/dev/null || command -v OliveTin &>/dev/null
}

describe() {
  echo -e "${TAB}  - OliveTin .deb from the latest GitHub release"
}

install() {
  fetch_gh_release "olivetin" "$RELEASE_REPO" "binary"
  msg_info "Enabling service"
  enable_service "$SERVICE_NAME"
  msg_ok "Enabled service"
  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
  msg_note "Actions are configured in /etc/OliveTin/config.yaml"
}

update() {
  gh_release_available "olivetin" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  fetch_gh_release "olivetin" "$RELEASE_REPO" "binary"
  restart_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  stop_service "$SERVICE_NAME"
  remove_packages olivetin
  rm -f "$HOME/.olivetin"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
