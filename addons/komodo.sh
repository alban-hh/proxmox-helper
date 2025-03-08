#!/usr/bin/env bash
APP="Komodo"
APP_SLUG="komodo"
INSTALL_PATH="/opt/komodo"
COMPOSE_ENV="${INSTALL_PATH}/compose.env"
UPSTREAM="https://raw.githubusercontent.com/moghtech/komodo/main/compose"
DEFAULT_PORT=9120
COMPOSE_FILE=""

PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  confirm_not_pve_host
  get_local_ip
}

is_installed() {
  [[ -d "$INSTALL_PATH" ]]
}

describe() {
  echo -e "${TAB}  - Komodo via Docker Compose"
  echo -e "${TAB}  - MongoDB or FerretDB (your choice)"
}

komodo_compose() {
  $STD docker compose -p komodo -f "$COMPOSE_FILE" --env-file "$COMPOSE_ENV" "$@"
}

find_compose_file() {
  COMPOSE_FILE="$(find "$INSTALL_PATH" -maxdepth 1 -type f -name '*.compose.yaml' | head -n1)"
  if [[ -z "$COMPOSE_FILE" ]]; then
    msg_error "No compose file found in ${INSTALL_PATH}."
    exit 233
  fi
  case "$(basename "$COMPOSE_FILE")" in
  sqlite.compose.yaml | postgres.compose.yaml)
    msg_error "This Komodo setup uses SQLite or PostgreSQL, which upstream dropped in v1.18. Migrate to MongoDB or FerretDB first."
    exit 238
    ;;
  esac
}

choose_database() {
  local choice
  echo -e "${TAB}Choose the database for Komodo:"
  echo -e "${TAB}  1) MongoDB (recommended)"
  echo -e "${TAB}  2) FerretDB"
  choice="$(ask "Enter your choice" "1")"
  case "$choice" in
  2) echo "ferretdb.compose.yaml" ;;
  *) echo "mongo.compose.yaml" ;;
  esac
}

write_env() {
  local admin_password="$1"
  curl -fsSL "${UPSTREAM}/compose.env" -o "$COMPOSE_ENV"
  sed -i "s/^KOMODO_DATABASE_USERNAME=.*/KOMODO_DATABASE_USERNAME=komodo_admin/" "$COMPOSE_ENV"
  sed -i "s/^KOMODO_DATABASE_PASSWORD=.*/KOMODO_DATABASE_PASSWORD=$(random_alnum 24)/" "$COMPOSE_ENV"
  sed -i "s/^KOMODO_INIT_ADMIN_PASSWORD=.*/KOMODO_INIT_ADMIN_PASSWORD=${admin_password}/" "$COMPOSE_ENV"
  sed -i "s/^KOMODO_WEBHOOK_SECRET=.*/KOMODO_WEBHOOK_SECRET=$(random_alnum 32)/" "$COMPOSE_ENV"
  sed -i "s/^KOMODO_JWT_SECRET=.*/KOMODO_JWT_SECRET=$(random_alnum 32)/" "$COMPOSE_ENV"
}

install() {
  local db_compose admin_password
  ensure_docker
  db_compose="$(choose_database)"
  admin_password="$(random_alnum 12)"

  msg_info "Creating ${INSTALL_PATH}"
  mkdir -p "$INSTALL_PATH"
  msg_ok "Created ${INSTALL_PATH}"

  msg_info "Downloading ${db_compose}"
  COMPOSE_FILE="${INSTALL_PATH}/${db_compose}"
  curl -fsSL "${UPSTREAM}/${db_compose}" -o "$COMPOSE_FILE"
  msg_ok "Downloaded ${db_compose}"

  msg_info "Configuring environment"
  write_env "$admin_password"
  msg_ok "Configured environment"

  msg_info "Starting ${APP}"
  komodo_compose up -d
  msg_ok "Started ${APP}"

  printf 'Komodo admin user: admin\nKomodo admin password: %s\n' "$admin_password" >>~/komodo.creds
  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
  msg_note "Login: admin / ${admin_password}"
  msg_note "Credentials saved to ~/komodo.creds"
}

migrate_env() {
  sed -i 's/^COMPOSE_KOMODO_IMAGE_TAG=latest/COMPOSE_KOMODO_IMAGE_TAG=2/' "$COMPOSE_ENV"
  sed -i 's/^KOMODO_DB_USERNAME=/KOMODO_DATABASE_USERNAME=/;s/^KOMODO_DB_PASSWORD=/KOMODO_DATABASE_PASSWORD=/' "$COMPOSE_ENV"
  sed -i '/^KOMODO_PASSKEY=/d' "$COMPOSE_ENV"
  grep -q 'PERIPHERY_CORE_PUBLIC_KEYS' "$COMPOSE_ENV" || echo 'PERIPHERY_CORE_PUBLIC_KEYS=file:/config/keys/core.pub' >>"$COMPOSE_ENV"
  grep -q 'COMPOSE_KOMODO_BACKUPS_PATH=' "$COMPOSE_ENV" || echo 'COMPOSE_KOMODO_BACKUPS_PATH=/etc/komodo/backups' >>"$COMPOSE_ENV"
}

update() {
  local stamp backup
  find_compose_file
  stamp="$(date +%Y%m%d_%H%M%S)"
  backup="${COMPOSE_FILE}.bak_${stamp}"

  msg_info "Updating ${APP}"
  cp "$COMPOSE_FILE" "$backup"
  cp "$COMPOSE_ENV" "${COMPOSE_ENV}.bak_${stamp}" 2>/dev/null || true
  if ! curl -fsSL "${UPSTREAM}/$(basename "$COMPOSE_FILE")" -o "$COMPOSE_FILE"; then
    mv "$backup" "$COMPOSE_FILE"
    msg_error "Failed to download the latest compose file."
    exit 115
  fi
  migrate_env
  komodo_compose pull
  komodo_compose up -d
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  find_compose_file
  komodo_compose down --volumes --remove-orphans
  rm -rf "$INSTALL_PATH"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
