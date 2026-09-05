#!/usr/bin/env bash
APP="Arcane"
APP_SLUG="arcane"
INSTALL_PATH="/opt/arcane"
COMPOSE_FILE="${INSTALL_PATH}/compose.yaml"
ENV_FILE="${INSTALL_PATH}/.env"
PROJECTS_DIR="/etc/arcane/projects"
BUILDS_DIR="/etc/arcane/builds"
ARCANE_UID=65532
DEFAULT_PORT=3552

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd)" || PXH_ROOT=""
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  confirm_not_pve_host
  get_local_ip
}

is_installed() {
  [[ -f "$COMPOSE_FILE" ]]
}

describe() {
  echo -e "${TAB}  - Arcane via Docker Compose"
}

configure_files() {
  local encryption_key jwt_secret
  encryption_key="$(random_alnum 32)"
  jwt_secret="$(random_alnum 32)"
  msg_info "Configuring compose and env files"
  sed -i "s|/host/path/to/projects|${PROJECTS_DIR}|g" "$COMPOSE_FILE"
  sed -i "s|/host/path/to/builds|${BUILDS_DIR}|g" "$COMPOSE_FILE"
  sed -i "s|ENCRYPTION_KEY=.*|ENCRYPTION_KEY=${encryption_key}|g" "$COMPOSE_FILE"
  sed -i "s|JWT_SECRET=.*|JWT_SECRET=${jwt_secret}|g" "$COMPOSE_FILE"
  sed -i "s|APP_URL=.*|APP_URL=http://localhost:${DEFAULT_PORT}|g" "$ENV_FILE"
  sed -i '/^ENCRYPTION_KEY=/d;/^JWT_SECRET=/d' "$ENV_FILE"
  msg_ok "Configured compose and env files"
}

install() {
  ensure_docker
  msg_info "Creating directories"
  mkdir -p "$INSTALL_PATH" "$PROJECTS_DIR" "$BUILDS_DIR"
  chown -R "${ARCANE_UID}:${ARCANE_UID}" "$PROJECTS_DIR" "$BUILDS_DIR"
  msg_ok "Created ${INSTALL_PATH}, ${PROJECTS_DIR} and ${BUILDS_DIR}"

  msg_info "Downloading compose and env files"
  curl -fsSL "https://raw.githubusercontent.com/getarcaneapp/arcane/refs/heads/main/docker/examples/compose.basic.yaml" -o "$COMPOSE_FILE"
  curl -fsSL "https://raw.githubusercontent.com/getarcaneapp/arcane/refs/heads/main/.env.example" -o "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  msg_ok "Downloaded compose and env files"

  configure_files

  msg_info "Starting ${APP}"
  compose_up "$INSTALL_PATH"
  msg_ok "Started ${APP}"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
  msg_note "Default login: arcane / arcane-admin"
  msg_warn "You will be asked to change the password on first access."
}

update() {
  chown -R "${ARCANE_UID}:${ARCANE_UID}" "$PROJECTS_DIR" "$BUILDS_DIR" 2>/dev/null || true
  compose_update "$INSTALL_PATH"
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  compose_down "$INSTALL_PATH"
  rm -rf "$INSTALL_PATH"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
