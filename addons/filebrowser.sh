#!/usr/bin/env bash
APP="FileBrowser"
APP_SLUG="filebrowser"
RELEASE_REPO="filebrowser/filebrowser"
BIN_PATH="/usr/local/bin/filebrowser"
DB_PATH="/usr/local/proxmox-helper/filebrowser.db"
SERVICE_NAME="filebrowser"
DEFAULT_PORT=8080

PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  get_local_ip
  if on_pve_host; then
    msg_warn "On the Proxmox host only the boot disk is visible; passthrough drives will not be indexed."
    confirm "Continue on the Proxmox host anyway?" || exit 0
  fi
}

is_installed() {
  [[ -f "$BIN_PATH" ]]
}

describe() {
  echo -e "${TAB}  - FileBrowser binary in /usr/local/bin"
  echo -e "${TAB}  - Database in ${DB_PATH}"
  echo -e "${TAB}  - System service"
}

deploy_binary() {
  fetch_gh_release "filebrowser" "$RELEASE_REPO" "prebuild" "latest" "/opt/filebrowser-dist" "linux-$(arch_resolve)-filebrowser.tar.gz"
  install -m 755 /opt/filebrowser-dist/filebrowser "$BIN_PATH"
  rm -rf /opt/filebrowser-dist
}

configure() {
  local port="$1"
  local password="$2"
  cd "$PXH_STATE_DIR"
  $STD filebrowser config init -a 0.0.0.0 -p "$port" -d "$DB_PATH"
  $STD filebrowser config set -a 0.0.0.0 -p "$port" -d "$DB_PATH"
  if [[ -z "$password" ]]; then
    $STD filebrowser config set --auth.method=noauth -d "$DB_PATH"
    $STD filebrowser users add admin "$(random_alnum 16)" --perm.admin -d "$DB_PATH"
  else
    $STD filebrowser users add admin "$password" --perm.admin -d "$DB_PATH"
  fi
}

create_service() {
  local port="$1"
  if is_alpine; then
    install_openrc_service "$SERVICE_NAME" "command=\"${BIN_PATH}\"
command_args=\"-r / -d ${DB_PATH} -p ${port}\"
command_background=true
pidfile=\"/run/filebrowser.pid\"
directory=\"${PXH_STATE_DIR}\"

depend() {
  need net
}"
  else
    install_systemd_service "$SERVICE_NAME" "[Unit]
Description=FileBrowser
After=network-online.target

[Service]
User=root
WorkingDirectory=${PXH_STATE_DIR}
ExecStart=${BIN_PATH} -r / -d ${DB_PATH} -p ${port}
Restart=always

[Install]
WantedBy=multi-user.target"
  fi
  enable_service "$SERVICE_NAME"
}

install() {
  local port password=""
  port="$(ask "Port" "$DEFAULT_PORT")"
  if ! confirm "Skip authentication (open to anyone on the network)?"; then
    password="$(random_alnum 16)"
  fi

  msg_info "Installing dependencies"
  ensure_packages tar curl
  msg_ok "Installed dependencies"

  deploy_binary

  msg_info "Preparing database"
  ensure_state_dir
  touch "$DB_PATH"
  chmod 644 "$DB_PATH"
  msg_ok "Prepared ${DB_PATH}"

  msg_info "Configuring ${APP}"
  configure "$port" "$password"
  msg_ok "Configured ${APP}"

  msg_info "Creating service"
  create_service "$port"
  msg_ok "Created service"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${port}${CL}"
  if [[ -n "$password" ]]; then
    msg_note "Login: admin / ${password}"
  else
    msg_warn "Authentication is disabled."
  fi
}

update() {
  gh_release_available "filebrowser" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  stop_service "$SERVICE_NAME"
  deploy_binary
  start_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  rm -f "$BIN_PATH" "$DB_PATH" "$HOME/.filebrowser"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
