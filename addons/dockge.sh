#!/usr/bin/env bash
APP="Dockge"
APP_SLUG="dockge"
INSTALL_PATH="/opt/dockge"
STACKS_PATH="/opt/stacks"
COMPOSE_FILE="${INSTALL_PATH}/compose.yaml"
DEFAULT_PORT=5001

PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  confirm_not_pve_host
  get_local_ip
}

is_installed() {
  [[ -f "$COMPOSE_FILE" ]]
}

describe() {
  echo -e "${TAB}  - Dockge via Docker Compose"
  echo -e "${TAB}  - Stacks directory at ${STACKS_PATH}"
}

install() {
  ensure_docker
  msg_info "Creating directories"
  mkdir -p "$INSTALL_PATH" "$STACKS_PATH"
  msg_ok "Created ${INSTALL_PATH} and ${STACKS_PATH}"

  msg_info "Downloading compose file"
  curl -fsSL "https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml" -o "$COMPOSE_FILE"
  msg_ok "Downloaded compose file"

  msg_info "Starting ${APP}"
  compose_up "$INSTALL_PATH"
  msg_ok "Started ${APP}"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
}

update() {
  compose_update "$INSTALL_PATH"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  (cd "$INSTALL_PATH" && $STD docker compose down --remove-orphans)
  rm -rf "$INSTALL_PATH"
  remove_update_script
  msg_ok "Removed ${APP}"
  msg_warn "Stacks in ${STACKS_PATH} were kept. Delete them manually if you no longer need them."
}

run_addon "$@"
