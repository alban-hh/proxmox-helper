#!/usr/bin/env bash
APP="Pi-hole Exporter"
APP_SLUG="pihole-exporter"
RELEASE_REPO="eko/pihole-exporter"
INSTALL_PATH="/opt/pihole-exporter"
BINARY_PATH="${INSTALL_PATH}/pihole-exporter"
CONFIG_PATH="/opt/pihole-exporter.env"
SERVICE_NAME="pihole-exporter"
DEFAULT_PORT=9617

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  get_local_ip
}

is_installed() {
  [[ -f "$BINARY_PATH" ]]
}

describe() {
  echo -e "${TAB}  - Go toolchain"
  echo -e "${TAB}  - pihole-exporter built from source in ${INSTALL_PATH}"
}

deploy_release() {
  fetch_gh_release "pihole-exporter" "$RELEASE_REPO" "tarball" "latest" "$INSTALL_PATH"
}

build_app() {
  msg_info "Building ${APP}"
  (cd "$INSTALL_PATH" && $STD /usr/local/bin/go build -o ./pihole-exporter)
  msg_ok "Built ${APP}"
}

write_config() {
  local protocol host port password skip_tls=false
  protocol="$(ask "Pi-hole protocol (http/https)" "https")"
  host="$(ask "Pi-hole hostname" "127.0.0.1")"
  port="$(ask "Pi-hole port" "443")"
  password="$(ask_secret "Pi-hole password")"
  confirm "Skip TLS verification (self-signed certificate)?" && skip_tls=true
  cat >"$CONFIG_PATH" <<ENV
PIHOLE_PASSWORD="${password}"
PIHOLE_HOSTNAME="${host}"
PIHOLE_PORT="${port}"
SKIP_TLS_VERIFICATION="${skip_tls}"
PIHOLE_PROTOCOL="${protocol}"
ENV
  chmod 600 "$CONFIG_PATH"
}

create_service() {
  if is_alpine; then
    install_openrc_service "$SERVICE_NAME" "name=\"pihole-exporter\"
description=\"Pi-hole exporter for Prometheus\"
command=\"${BINARY_PATH}\"
command_background=true
directory=\"${INSTALL_PATH}\"
pidfile=\"/run/pihole-exporter.pid\"
output_log=\"/var/log/pihole-exporter.log\"
error_log=\"/var/log/pihole-exporter.log\"

depend() {
  need net
  after firewall
}

start_pre() {
  if [ -f \"${CONFIG_PATH}\" ]; then
    export \$(grep -v '^#' ${CONFIG_PATH} | xargs)
  fi
}"
  else
    install_systemd_service "$SERVICE_NAME" "[Unit]
Description=Pi-hole exporter for Prometheus
After=network.target

[Service]
User=root
WorkingDirectory=${INSTALL_PATH}
EnvironmentFile=${CONFIG_PATH}
ExecStart=${BINARY_PATH}
Restart=always

[Install]
WantedBy=multi-user.target"
  fi
  enable_service "$SERVICE_NAME"
}

install() {
  deploy_release
  setup_go
  build_app

  msg_info "Writing configuration"
  write_config
  msg_ok "Wrote ${CONFIG_PATH}"

  msg_info "Creating service"
  create_service
  msg_ok "Created service"

  ensure_update_script
  echo
  msg_ok "Metrics: ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}/metrics${CL}"
}

update() {
  gh_release_available "pihole-exporter" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  stop_service "$SERVICE_NAME"
  deploy_release
  setup_go
  build_app
  start_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  rm -rf "$INSTALL_PATH"
  rm -f "$CONFIG_PATH" "$HOME/.pihole-exporter"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
