docker_available() {
  command -v docker &>/dev/null && docker compose version &>/dev/null
}

require_docker() {
  if ! command -v docker &>/dev/null; then
    msg_error "Docker is not installed. ${APP:-This addon} expects an existing Docker host."
    exit 237
  fi
  if ! docker compose version &>/dev/null; then
    msg_error "The Docker Compose plugin is missing."
    exit 237
  fi
  msg_ok "Docker $(docker --version | cut -d' ' -f3 | tr -d ',') with Compose is available"
}

install_docker() {
  msg_info "Installing Docker"
  if is_alpine; then
    $STD apk add --no-cache docker docker-cli-compose
    $STD rc-update add docker default
    $STD rc-service docker start
  else
    ensure_packages ca-certificates curl gpg
    . /etc/os-release
    setup_deb822_repo "docker" "https://download.docker.com/linux/${ID}/gpg" "https://download.docker.com/linux/${ID}" "$VERSION_CODENAME" "stable"
    install_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    mkdir -p /etc/docker
    [[ -f /etc/docker/daemon.json ]] || echo '{ "log-driver": "journald" }' >/etc/docker/daemon.json
    $STD systemctl enable --now docker
  fi
  msg_ok "Installed Docker $(docker --version | cut -d' ' -f3 | tr -d ',')"
}

ensure_docker() {
  if docker_available; then
    msg_ok "Docker $(docker --version | cut -d' ' -f3 | tr -d ',') with Compose is available"
    return 0
  fi
  msg_warn "Docker is not installed."
  if ! confirm "Install Docker now?"; then
    msg_error "Docker is required for ${APP:-this addon}."
    exit 254
  fi
  install_docker
  docker_available || {
    msg_error "Docker is still unavailable after installation."
    exit 237
  }
}

compose_up() {
  local dir="$1"
  (cd "$dir" && $STD docker compose up -d --remove-orphans)
}

compose_pull() {
  local dir="$1"
  (cd "$dir" && $STD docker compose pull)
}

compose_down() {
  local dir="$1"
  (cd "$dir" && $STD docker compose down --volumes --remove-orphans)
}

compose_update() {
  local dir="$1"
  msg_info "Pulling latest ${APP} image"
  compose_pull "$dir"
  msg_ok "Pulled latest image"
  msg_info "Restarting ${APP}"
  compose_up "$dir"
  msg_ok "Restarted ${APP}"
}
