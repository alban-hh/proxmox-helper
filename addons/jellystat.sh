#!/usr/bin/env bash
APP="Jellystat"
APP_SLUG="jellystat"
RELEASE_REPO="CyferShepard/Jellystat"
INSTALL_PATH="/opt/jellystat"
CONFIG_PATH="${INSTALL_PATH}/.env"
CREDS_FILE="/root/jellystat.creds"
SERVICE_NAME="jellystat"
DB_NAME="jellystat"
DB_USER="jellystat"
DEFAULT_PORT=3000

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd)" || PXH_ROOT=""
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  require_debian_like
  get_local_ip
}

is_installed() {
  [[ -f "${INSTALL_PATH}/package.json" ]]
}

describe() {
  echo -e "${TAB}  - Node.js 22"
  echo -e "${TAB}  - PostgreSQL 17"
  echo -e "${TAB}  - Jellystat built from source in ${INSTALL_PATH}"
}

deploy_release() {
  fetch_gh_release "jellystat" "$RELEASE_REPO" "tarball" "latest" "$INSTALL_PATH"
}

build_app() {
  msg_info "Installing npm dependencies"
  (cd "$INSTALL_PATH" && $STD npm install)
  msg_ok "Installed npm dependencies"
  msg_info "Building ${APP}"
  (cd "$INSTALL_PATH" && $STD npm run build)
  msg_ok "Built ${APP}"
}

setup_database() {
  if pg_database_exists "$DB_NAME"; then
    msg_warn "Database ${DB_NAME} already exists."
    DB_PASS="$(ask_secret "Existing password for ${DB_USER}")"
    return 0
  fi
  DB_PASS="$(random_alnum 20)"
  msg_info "Creating PostgreSQL database"
  pg_create_database "$DB_NAME" "$DB_USER" "$DB_PASS"
  msg_ok "Created database ${DB_NAME}"
}

write_config() {
  local jwt_secret
  jwt_secret="$(random_alnum 32)"
  cat >"$CONFIG_PATH" <<ENV
POSTGRES_USER=${DB_USER}
POSTGRES_PASSWORD=${DB_PASS}
POSTGRES_IP=localhost
POSTGRES_PORT=5432
POSTGRES_DB=${DB_NAME}
JWT_SECRET=${jwt_secret}
JS_LISTEN_IP=0.0.0.0
JS_BASE_URL=/
TZ=$(cat /etc/timezone 2>/dev/null || echo UTC)
REJECT_SELF_SIGNED_CERTIFICATES=true
ENV
  chmod 600 "$CONFIG_PATH"
  printf 'Database: %s\nUser: %s\nPassword: %s\nJWT secret: %s\nWeb UI: http://%s:%s\n' \
    "$DB_NAME" "$DB_USER" "$DB_PASS" "$jwt_secret" "$LOCAL_IP" "$DEFAULT_PORT" >"$CREDS_FILE"
  chmod 600 "$CREDS_FILE"
}

create_service() {
  install_systemd_service "$SERVICE_NAME" "[Unit]
Description=Jellystat
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_PATH}/backend
EnvironmentFile=${CONFIG_PATH}
ExecStart=/usr/bin/node ${INSTALL_PATH}/backend/server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"
  enable_service "$SERVICE_NAME"
}

install() {
  NODE_VERSION="22" setup_nodejs
  PG_VERSION="17" setup_postgresql
  setup_database
  deploy_release
  build_app

  msg_info "Writing configuration"
  write_config
  msg_ok "Wrote ${CONFIG_PATH}"

  msg_info "Creating service"
  create_service
  msg_ok "Created service"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
  msg_note "Credentials saved to ${CREDS_FILE}"
  msg_warn "Point it at your Jellyfin server on first access."
}

update() {
  gh_release_available "jellystat" "$RELEASE_REPO" || return 0
  msg_info "Updating ${APP}"
  stop_service "$SERVICE_NAME"
  create_backup "$CONFIG_PATH"
  CLEAN_INSTALL=1 deploy_release
  restore_backup
  build_app
  start_service "$SERVICE_NAME"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  remove_service "$SERVICE_NAME"
  rm -rf "$INSTALL_PATH"
  rm -f "$CREDS_FILE" "$HOME/.jellystat"
  remove_update_script
  msg_ok "Removed ${APP}"
  if confirm "Also drop the PostgreSQL database ${DB_NAME}?"; then
    pg_drop_database "$DB_NAME" "$DB_USER"
    msg_ok "Dropped database ${DB_NAME}"
  fi
}

run_addon "$@"
