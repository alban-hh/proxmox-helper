#!/usr/bin/env bash
APP="AdGuardHome Sync"
APP_SLUG="adguardhome-sync"
RELEASE_REPO="bakito/adguardhome-sync"
INSTALL_PATH="/opt/adguardhome-sync"
CONFIG_PATH="${INSTALL_PATH}/adguardhome-sync.yaml"
SERVICE_NAME="adguardhome-sync"
DEFAULT_PORT=8080

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd)" || PXH_ROOT=""
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  get_local_ip
}

is_installed() {
  [[ -f "${INSTALL_PATH}/adguardhome-sync" ]]
}

describe() {
  echo -e "${TAB}  - adguardhome-sync binary in ${INSTALL_PATH}"
  echo -e "${TAB}  - Service with a web UI on port ${DEFAULT_PORT}"
}

deploy_release() {
  fetch_gh_release "adguardhome-sync" "$RELEASE_REPO" "prebuild" "latest" "$INSTALL_PATH" "adguardhome-sync_*_linux_$(arch_resolve).tar.gz"
}

normalize_url() {
  local url="$1"
  [[ "$url" =~ ^https?:// ]] || url="http://${url}"
  echo "$url"
}

write_config() {
  local origin_url="$1" origin_user="$2" origin_pass="$3"
  local replica_url="$4" replica_user="$5" replica_pass="$6"
  cat >"$CONFIG_PATH" <<CONFIG
cron: "0 */2 * * *"
runOnStart: true
continueOnError: false
origin:
  url: "${origin_url}"
  username: "${origin_user}"
  password: "${origin_pass}"
  insecureSkipVerify: false
replicas:
  - url: "${replica_url}"
    username: "${replica_user}"
    password: "${replica_pass}"
    insecureSkipVerify: false
api:
  port: ${DEFAULT_PORT}
  darkMode: true
  metrics:
    enabled: false
features:
  dns:
    accessLists: true
    serverConfig: true
    rewrites: true
  dhcp:
    serverConfig: true
    staticLeases: true
  generalSettings: true
  queryLogConfig: true
  statsConfig: true
  clientSettings: true
  services: true
  filters: true
  theme: true
CONFIG
  chmod 600 "$CONFIG_PATH"
}

create_service() {
  if is_alpine; then
    install_openrc_service "$SERVICE_NAME" "name=\"adguardhome-sync\"
description=\"AdGuardHome Sync\"
command=\"${INSTALL_PATH}/adguardhome-sync\"
command_args=\"run --config ${CONFIG_PATH}\"
command_background=true
pidfile=\"/run/adguardhome-sync.pid\"
output_log=\"/var/log/adguardhome-sync.log\"
error_log=\"/var/log/adguardhome-sync.log\"

depend() {
  need net
  after firewall
}"
  else
    install_systemd_service "$SERVICE_NAME" "[Unit]
Description=AdGuardHome Sync
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_PATH}/adguardhome-sync run --config ${CONFIG_PATH}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"
  fi
  enable_service "$SERVICE_NAME"
}

install() {
  local origin_url origin_user origin_pass replica_url replica_user replica_pass
  deploy_release

  echo
  msg_note "The origin is your primary AdGuard Home; the replica syncs from it."
  echo
  origin_url="$(normalize_url "$(ask "Origin URL" "http://192.168.1.1")")"
  origin_user="$(ask "Origin username" "admin")"
  origin_pass="$(ask_secret "Origin password")"
  echo
  replica_url="$(normalize_url "$(ask "Replica URL" "http://192.168.1.2")")"
  replica_user="$(ask "Replica username" "admin")"
  replica_pass="$(ask_secret "Replica password")"
  echo

  msg_info "Writing configuration"
  write_config "$origin_url" "$origin_user" "$origin_pass" "$replica_url" "$replica_user" "$replica_pass"
  msg_ok "Wrote ${CONFIG_PATH}"

  msg_info "Creating service"
  create_service
  msg_ok "Created service"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
  msg_note "Add more replicas in ${CONFIG_PATH}"
}

update() {
  gh_release_available "adguardhome-sync" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  stop_service "$SERVICE_NAME"
  create_backup "$CONFIG_PATH"
  CLEAN_INSTALL=1 deploy_release
  restore_backup
  start_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  rm -rf "$INSTALL_PATH"
  rm -f "$HOME/.adguardhome-sync"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
