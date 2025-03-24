#!/usr/bin/env bash
APP="Copyparty"
APP_SLUG="copyparty"
RELEASE_REPO="9001/copyparty"
BIN_PATH="/usr/local/bin/copyparty-sfx.py"
CONF_PATH="/etc/copyparty.conf"
LOG_PATH="/var/log/copyparty"
DATA_PATH="/var/lib/copyparty"
SVC_USER="copyparty"
SERVICE_NAME="copyparty"
DEFAULT_PORT=3923

PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  get_local_ip
  persist_usr_local_bin
}

is_installed() {
  [[ -f "$BIN_PATH" ]]
}

describe() {
  echo -e "${TAB}  - Copyparty (single-file Python server)"
  echo -e "${TAB}  - Pillow and ffmpeg for thumbnails"
  echo -e "${TAB}  - Dedicated ${SVC_USER} user and service"
}

deploy_binary() {
  fetch_gh_release "copyparty-sfx.py" "$RELEASE_REPO" "singlefile" "latest" "/usr/local/bin" "copyparty-sfx.py"
  chown "${SVC_USER}:${SVC_USER}" "$BIN_PATH"
}

write_config() {
  local port="$1"
  local admin_user="$2"
  local admin_pass="$3"
  cat >"$CONF_PATH" <<CONFIG
[global]
  p: ${port}
  ansi
  e2dsa
  e2ts
  theme: 2
  grid
  no-robots
  force-js
  lo: ${LOG_PATH}/cpp-%Y-%m%d.txt.xz
CONFIG
  if [[ -n "$admin_user" ]]; then
    printf '\n[accounts]\n  %s: %s\n' "$admin_user" "$admin_pass" >>"$CONF_PATH"
    printf '\n[/]\n  %s\n  accs:\n    rw: *\n    rwmda: %s\n' "$DATA_PATH" "$admin_user" >>"$CONF_PATH"
  else
    printf '\n[/]\n  %s\n  accs:\n    rw: *\n' "$DATA_PATH" >>"$CONF_PATH"
  fi
  chmod 640 "$CONF_PATH"
  chown "${SVC_USER}:${SVC_USER}" "$CONF_PATH"
}

create_service() {
  if is_alpine; then
    install_openrc_service "$SERVICE_NAME" "name=\"copyparty\"
description=\"Copyparty file server\"
command=\"/usr/bin/python3\"
command_args=\"${BIN_PATH} -c ${CONF_PATH}\"
command_background=true
command_user=\"${SVC_USER}\"
directory=\"${DATA_PATH}\"
pidfile=\"/run/copyparty.pid\"
output_log=\"${LOG_PATH}/copyparty.log\"
error_log=\"${LOG_PATH}/copyparty.err\"

depend() {
  need net
}"
  else
    install_systemd_service "$SERVICE_NAME" "[Unit]
Description=Copyparty file server
After=network.target

[Service]
User=${SVC_USER}
Group=${SVC_USER}
WorkingDirectory=${DATA_PATH}
ExecStart=/usr/bin/python3 ${BIN_PATH} -c ${CONF_PATH}
Restart=always
StandardOutput=append:${LOG_PATH}/copyparty.log
StandardError=append:${LOG_PATH}/copyparty.err

[Install]
WantedBy=multi-user.target"
  fi
  enable_service "$SERVICE_NAME"
}

install() {
  local port data_path admin_user="" admin_pass=""
  echo
  port="$(ask "Port" "$DEFAULT_PORT")"
  data_path="$(ask "Data directory" "$DATA_PATH")"
  if confirm "Enable authentication?"; then
    admin_user="$(ask "Admin username" "admin")"
    admin_pass="$(ask_secret "Admin password (empty for a generated one)")"
    [[ -z "$admin_pass" ]] && admin_pass="$(random_alnum 16)"
  fi
  DATA_PATH="$data_path"

  msg_info "Installing dependencies"
  if is_alpine; then
    ensure_packages python3 py3-pillow ffmpeg curl
  else
    ensure_packages python3 python3-pil ffmpeg curl
  fi
  msg_ok "Installed dependencies"

  msg_info "Creating user and directories"
  create_system_user "$SVC_USER" "$DATA_PATH"
  owned_dirs "${SVC_USER}:${SVC_USER}" "$DATA_PATH" "$LOG_PATH"
  msg_ok "Created ${SVC_USER} user, ${DATA_PATH} and ${LOG_PATH}"

  deploy_binary

  msg_info "Writing configuration"
  write_config "$port" "$admin_user" "$admin_pass"
  msg_ok "Wrote ${CONF_PATH}"

  msg_info "Creating service"
  create_service
  msg_ok "Created service"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${port}${CL}"
  msg_note "Storage: ${DATA_PATH}"
  msg_note "Config: ${CONF_PATH}"
  [[ -n "$admin_user" ]] && msg_note "Login: ${admin_user} / ${admin_pass}"
}

update() {
  gh_release_available "copyparty-sfx.py" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  stop_service "$SERVICE_NAME"
  deploy_binary
  start_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  rm -f "$BIN_PATH" "$CONF_PATH" "$HOME/.copyparty-sfx.py"
  rm -rf "$DATA_PATH" "$LOG_PATH"
  remove_system_user "$SVC_USER"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
