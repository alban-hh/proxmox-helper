#!/usr/bin/env bash
APP="LXC Templates"
APP_SLUG="all-templates"
CTID=""

PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

cleanup_on_error() {
  local rc=$?
  if [[ -n "$CTID" ]] && pct status "$CTID" &>/dev/null; then
    container_is_running "$CTID" && pct stop "$CTID"
    pct destroy "$CTID"
  fi
  error_handler "$rc" "$BASH_COMMAND"
}

select_template() {
  local menu=() tag item width=0
  ensure_whiptail
  msg_info "Refreshing template list"
  $STD pveam update
  stop_spinner
  while read -r tag item; do
    ((${#item} + 2 > width)) && width=$((${#item} + 2))
    menu+=("$item" "$tag" "OFF")
  done < <(pveam available)
  whiptail --backtitle "$PXH_BACKTITLE" --title "LXC templates" --radiolist \
    "\nSelect a template to create a container from:\n" 16 $((width + 58)) 10 "${menu[@]}" 3>&1 1>&2 2>&3 | tr -d '"'
}

wait_for_ip() {
  local ctid="$1" attempt=0 ip=""
  while ((attempt < 5)); do
    ip="$(pct exec "$ctid" -- ip -4 addr show dev eth0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)"
    [[ -n "$ip" ]] && break
    sleep 5
    ((attempt++))
  done
  echo "${ip:-not found}"
}

main() {
  local template name password template_storage container_storage ip
  trap cleanup_on_error ERR
  msg_note "Creates a plain LXC container from any template Proxmox offers."
  confirm "Proceed?" || exit 0

  template="$(select_template)"
  [[ -n "$template" ]] || exit 0
  name="$(grep -oE '^[^-]+-[^-]+' <<<"$template")"
  password="$(random_alnum 14)"
  CTID="$(next_free_vmid)"

  template_storage="$(select_storage template)"
  container_storage="$(select_storage container)"
  msg_ok "Template storage: ${template_storage}, container storage: ${container_storage}"

  msg_info "Downloading template (this can take a while)"
  $STD pveam download "$template_storage" "$template"
  msg_ok "Downloaded ${template}"

  msg_info "Creating container ${CTID}"
  $STD pct create "$CTID" "${template_storage}:vztmpl/${template}" \
    -arch "$(dpkg --print-architecture)" \
    -features keyctl=1,nesting=1 \
    -hostname "$name" \
    -tags proxmox-helper \
    -onboot 0 \
    -cores 2 \
    -memory 2048 \
    -password "$password" \
    -net0 name=eth0,bridge=vmbr0,ip=dhcp \
    -unprivileged 1 \
    -rootfs "${container_storage}:${PCT_DISK_SIZE:-8}"
  msg_ok "Created container ${CTID}"

  printf '%s password: %s\n' "$name" "$password" >>"$HOME/${name}.creds"

  msg_info "Starting container"
  pct start "$CTID"
  sleep 5
  ip="$(wait_for_ip "$CTID")"
  msg_ok "Container ${CTID} is running at ${ip}"

  echo
  msg_note "Login: root / ${password} (saved to ~/${name}.creds)"
}

run_tool "$@"
