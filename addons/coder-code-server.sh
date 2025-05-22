#!/usr/bin/env bash
APP="Coder Code Server"
APP_SLUG="coder-code-server"
RELEASE_REPO="coder/code-server"
CONFIG_PATH="${HOME}/.config/code-server/config.yaml"
SERVICE_NAME="code-server@root"
DEFAULT_PORT=8680

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  require_debian_like
  confirm_not_pve_host
  get_local_ip
}

is_installed() {
  command -v code-server &>/dev/null
}

describe() {
  echo -e "${TAB}  - code-server .deb from the latest GitHub release"
  echo -e "${TAB}  - Service listening on port ${DEFAULT_PORT}"
}

deploy_release() {
  fetch_gh_release "coder-code-server" "$RELEASE_REPO" "binary" "latest" "/opt/coder-code-server" "code-server_*_$(arch_resolve).deb"
}

write_config() {
  [[ -f "$CONFIG_PATH" ]] && return 0
  mkdir -p "$(dirname "$CONFIG_PATH")"
  cat >"$CONFIG_PATH" <<CONFIG
bind-addr: 0.0.0.0:${DEFAULT_PORT}
auth: none
password:
cert: false
CONFIG
}

install() {
  msg_info "Installing dependencies"
  ensure_packages curl git
  msg_ok "Installed dependencies"

  deploy_release

  msg_info "Configuring ${APP}"
  write_config
  enable_service "$SERVICE_NAME"
  restart_service "$SERVICE_NAME"
  service_is_active "$SERVICE_NAME" || {
    msg_error "code-server failed to start."
    exit 150
  }
  msg_ok "Configured ${APP}"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
  msg_warn "Authentication is off. Set auth: password in ${CONFIG_PATH} if this box is shared."
}

update() {
  gh_release_available "coder-code-server" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  deploy_release
  restart_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  remove_packages code-server
  rm -f "$HOME/.coder-code-server"
  remove_update_script
  msg_ok "Removed ${APP}"
  msg_note "Your settings in ${HOME}/.config/code-server were kept."
}

run_addon "$@"
