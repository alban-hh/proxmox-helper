#!/usr/bin/env bash
APP="Portainer"
APP_SLUG="portainer"
INSTALL_PATH="/opt/portainer"
COMPOSE_FILE="${INSTALL_PATH}/compose.yaml"
DEFAULT_PORT=9443

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd)" || PXH_ROOT=""
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

PORTAINER_IMAGE=""
COMPOSE_WORKDIR=""
COMPOSE_SERVICE=""

prepare() {
  confirm_not_pve_host
  get_local_ip
  require_docker
  detect_existing_container
}

detect_existing_container() {
  docker container inspect portainer &>/dev/null || return 0
  PORTAINER_IMAGE="$(docker inspect portainer --format '{{.Config.Image}}')"
  if [[ ! "$PORTAINER_IMAGE" =~ (^|/)portainer-(ce|ee)(:|@) ]]; then
    msg_error "A container named 'portainer' exists but does not run an official Portainer image."
    exit 10
  fi
  COMPOSE_WORKDIR="$(docker inspect portainer --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}')"
  COMPOSE_SERVICE="$(docker inspect portainer --format '{{index .Config.Labels "com.docker.compose.service"}}')"
  [[ "$COMPOSE_WORKDIR" == "<no value>" ]] && COMPOSE_WORKDIR=""
  [[ "$COMPOSE_SERVICE" == "<no value>" ]] && COMPOSE_SERVICE=""
}

is_installed() {
  [[ -f "$COMPOSE_FILE" || -n "$PORTAINER_IMAGE" ]]
}

describe() {
  echo -e "${TAB}  - Portainer CE via Docker Compose"
}

install() {
  msg_info "Creating ${INSTALL_PATH}"
  mkdir -p "$INSTALL_PATH"
  msg_ok "Created ${INSTALL_PATH}"

  msg_info "Downloading compose file"
  curl -fsSL "https://downloads.portainer.io/ce-sts/portainer-compose.yaml" -o "$COMPOSE_FILE"
  msg_ok "Downloaded compose file"

  msg_info "Starting ${APP}"
  compose_up "$INSTALL_PATH"
  msg_ok "Started ${APP}"

  ensure_update_script
  echo
  msg_ok "${APP} is reachable at ${BL}https://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
  msg_warn "Create the admin account on first access."
}

update_standalone() {
  local old_image_id latest_image_id was_running
  local -a run_args=(-d --name portainer)
  local -a command=()
  local line

  old_image_id="$(docker inspect portainer --format '{{.Image}}')"
  was_running="$(docker inspect portainer --format '{{.State.Running}}')"
  run_args+=(--restart "$(docker inspect portainer --format '{{.HostConfig.RestartPolicy.Name}}')")

  while IFS='|' read -r host_ip host_port container_port; do
    [[ -z "$container_port" ]] && continue
    run_args+=(-p "${host_ip:+$host_ip:}${host_port}:${container_port}")
  done < <(docker inspect portainer --format '{{range $p, $conf := .HostConfig.PortBindings}}{{range $conf}}{{.HostIp}}|{{.HostPort}}|{{$p}}{{println}}{{end}}{{end}}')

  while IFS='|' read -r kind source destination mode; do
    [[ -z "$destination" ]] && continue
    run_args+=(-v "${source}:${destination}${mode:+:$mode}")
  done < <(docker inspect portainer --format '{{range .Mounts}}{{.Type}}|{{if eq .Type "volume"}}{{.Name}}{{else}}{{.Source}}{{end}}|{{.Destination}}|{{.Mode}}{{println}}{{end}}')

  while IFS= read -r line; do
    [[ -n "$line" ]] && run_args+=(-e "$line")
  done < <(docker inspect portainer --format '{{range .Config.Env}}{{println .}}{{end}}')

  while IFS= read -r line; do
    [[ -n "$line" ]] && command+=("$line")
  done < <(docker inspect portainer --format '{{range .Config.Cmd}}{{println .}}{{end}}')

  msg_info "Pulling latest ${APP} image"
  $STD docker pull "$PORTAINER_IMAGE"
  latest_image_id="$(docker image inspect "$PORTAINER_IMAGE" --format '{{.Id}}')"
  msg_ok "Pulled latest image"

  if [[ "$old_image_id" == "$latest_image_id" ]]; then
    msg_ok "${APP} is already up to date"
    return 0
  fi

  msg_info "Recreating ${APP}"
  [[ "$was_running" == "true" ]] && $STD docker stop portainer
  $STD docker rm portainer
  if ! $STD docker run "${run_args[@]}" "$PORTAINER_IMAGE" "${command[@]}"; then
    msg_warn "Update failed, restoring previous image"
    docker rm -f portainer &>/dev/null || true
    $STD docker run "${run_args[@]}" "$old_image_id" "${command[@]}"
    msg_error "Failed to update ${APP}; the previous container was restored."
    exit 10
  fi
  msg_ok "Recreated ${APP}"
}

update() {
  if [[ -f "$COMPOSE_FILE" ]]; then
    compose_update "$INSTALL_PATH"
  elif [[ -n "$COMPOSE_WORKDIR" && -d "$COMPOSE_WORKDIR" ]]; then
    msg_info "Pulling latest ${APP} image"
    (cd "$COMPOSE_WORKDIR" && $STD docker compose pull "$COMPOSE_SERVICE")
    msg_ok "Pulled latest image"
    msg_info "Restarting ${APP}"
    (cd "$COMPOSE_WORKDIR" && $STD docker compose up -d "$COMPOSE_SERVICE")
    msg_ok "Restarted ${APP}"
  else
    update_standalone
  fi
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  if [[ -f "$COMPOSE_FILE" ]]; then
    compose_down "$INSTALL_PATH"
  fi
  rm -rf "$INSTALL_PATH"
  remove_update_script
  msg_ok "Removed ${APP}"
}

run_addon "$@"
