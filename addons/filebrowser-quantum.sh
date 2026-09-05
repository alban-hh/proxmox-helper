#!/usr/bin/env bash
APP="FileBrowser Quantum"
APP_SLUG="filebrowser-quantum"
RELEASE_REPO="gtsteffaniak/filebrowser"
BIN_PATH="/usr/local/bin/filebrowser"
CONFIG_PATH="/usr/local/proxmox-helper/filebrowser-quantum.yaml"
SERVICE_NAME="filebrowser"
SOURCE_DIR="/"
DEFAULT_PORT=8080

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd)" || PXH_ROOT=""
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  get_local_ip
  if on_pve_host; then
    msg_warn "On the Proxmox host only the boot disk is visible; passthrough drives will not be indexed."
    confirm "Continue on the Proxmox host anyway?" || exit 0
  fi
  handle_legacy_install
}

handle_legacy_install() {
  local legacy_db="/usr/local/proxmox-helper/filebrowser.db"
  [[ -f "$legacy_db" && ! -f "$CONFIG_PATH" ]] || return 0
  msg_warn "Found a classic FileBrowser install."
  confirm "Remove it and continue with Quantum?" || exit 0
  msg_info "Removing classic FileBrowser"
  remove_service "$SERVICE_NAME"
  rm -f "$BIN_PATH" "$legacy_db" "$HOME/.filebrowser"
  rm -f /usr/local/bin/update_filebrowser
  msg_ok "Removed classic FileBrowser"
}

is_installed() {
  [[ -f "$BIN_PATH" && -f "$CONFIG_PATH" ]]
}

describe() {
  echo -e "${TAB}  - FileBrowser Quantum binary in /usr/local/bin"
  echo -e "${TAB}  - Config in ${CONFIG_PATH}"
  echo -e "${TAB}  - ffmpeg for previews"
}

deploy_binary() {
  fetch_gh_release "filebrowser-quantum" "$RELEASE_REPO" "singlefile" "latest" "/usr/local/bin" "linux-$(arch_resolve)-filebrowser"
  mv -f /usr/local/bin/filebrowser-quantum "$BIN_PATH"
}

write_config() {
  local port="$1"
  local password="$2"
  cat >"$CONFIG_PATH" <<CONFIG
server:
  port: ${port}
  sources:
    - path: "${SOURCE_DIR}"
      name: "RootFS"
      config:
        denyByDefault: false
        indexingIntervalMinutes: 240
        conditionals:
          rules:
            - neverWatchPath: "/proc"
            - neverWatchPath: "/sys"
            - neverWatchPath: "/dev"
            - neverWatchPath: "/run"
            - neverWatchPath: "/tmp"
            - neverWatchPath: "/lost+found"
CONFIG
  if [[ -z "$password" ]]; then
    printf 'auth:\n  methods:\n    noauth: true\n' >>"$CONFIG_PATH"
  else
    printf 'auth:\n  adminUsername: admin\n  adminPassword: %s\n' "$password" >>"$CONFIG_PATH"
  fi
  chmod 600 "$CONFIG_PATH"
}

create_service() {
  if is_alpine; then
    install_openrc_service "$SERVICE_NAME" "command=\"${BIN_PATH}\"
command_args=\"-c ${CONFIG_PATH}\"
command_background=true
directory=\"${PXH_STATE_DIR}\"
pidfile=\"/run/filebrowser.pid\"

depend() {
  need net
}"
  else
    install_systemd_service "$SERVICE_NAME" "[Unit]
Description=FileBrowser Quantum
After=network.target

[Service]
User=root
WorkingDirectory=${PXH_STATE_DIR}
ExecStart=${BIN_PATH} -c ${CONFIG_PATH}
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
  ensure_packages curl ffmpeg
  msg_ok "Installed dependencies"

  deploy_binary

  msg_info "Writing configuration"
  ensure_state_dir
  write_config "$port" "$password"
  msg_ok "Wrote ${CONFIG_PATH}"

  msg_info "Creating service"
  create_service
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
  gh_release_available "filebrowser-quantum" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  deploy_binary
  sed -i '/^\s*disableIndexing:/d' "$CONFIG_PATH"
  restart_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  rm -f "$BIN_PATH" "$CONFIG_PATH" "$HOME/.filebrowser-quantum"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
