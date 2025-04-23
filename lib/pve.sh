PXH_BACKTITLE="proxmox-helper"

ensure_whiptail() {
  command -v whiptail &>/dev/null || ensure_packages whiptail
}

select_container() {
  local prompt="$1"
  local node menu=() line ctid name width=0
  ensure_whiptail
  node="$(hostname)"
  while read -r line; do
    ctid="$(awk '{print $1}' <<<"$line")"
    name="$(awk '{print substr($0, 36)}' <<<"$line")"
    ((${#name} + 2 > width)) && width=$((${#name} + 2))
    menu+=("$ctid" "$name" "OFF")
  done < <(pct list | awk 'NR>1')
  if ((${#menu[@]} == 0)); then
    msg_error "No LXC containers found on ${node}."
    exit 1
  fi
  whiptail --backtitle "$PXH_BACKTITLE" --title "Containers on ${node}" --radiolist \
    "\n${prompt}\n" 16 $((width + 23)) 6 "${menu[@]}" 3>&1 1>&2 2>&3
}

container_is_running() {
  [[ "$(pct status "$1" | awk '{print $2}')" == "running" ]]
}

ensure_container_running() {
  local ctid="$1"
  container_is_running "$ctid" && return 0
  msg_info "Starting container ${ctid}"
  pct start "$ctid"
  while ! container_is_running "$ctid"; do
    sleep 2
  done
  msg_ok "Container ${ctid} is running"
}

container_distro() {
  pct exec "$1" -- sh -c '. /etc/os-release && echo "$ID"'
}

allow_tun_device() {
  local conf="/etc/pve/lxc/$1.conf"
  grep -q "lxc.cgroup2.devices.allow: c 10:200 rwm" "$conf" || echo "lxc.cgroup2.devices.allow: c 10:200 rwm" >>"$conf"
  grep -q "lxc.mount.entry: /dev/net/tun" "$conf" || echo "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file" >>"$conf"
}

add_container_tag() {
  local ctid="$1"
  local tag="$2"
  local conf="/etc/pve/lxc/${ctid}.conf"
  local tags
  tags="$(awk -F': ' '/^tags:/ {print $2}' "$conf")"
  [[ ";${tags// /};" == *";${tag};"* ]] && return 0
  pct set "$ctid" -tags "${tags:+$tags;}${tag}"
}

next_free_vmid() {
  local id
  id="$(pvesh get /cluster/nextid)"
  while [[ -f "/etc/pve/qemu-server/${id}.conf" || -f "/etc/pve/lxc/${id}.conf" ]] || lvs --noheadings -o lv_name 2>/dev/null | grep -qE "(^|[-_])${id}($|[-_])"; do
    id=$((id + 1))
  done
  echo "$id"
}

select_storage() {
  local class="$1"
  local content label menu=() line tag type free item width=0
  case "$class" in
  container)
    content="rootdir"
    label="container"
    ;;
  template)
    content="vztmpl"
    label="template"
    ;;
  *)
    msg_error "Unknown storage class: ${class}"
    exit 112
    ;;
  esac
  ensure_whiptail
  while read -r line; do
    tag="$(awk '{print $1}' <<<"$line")"
    type="$(awk '{printf "%-10s", $2}' <<<"$line")"
    free="$(numfmt --field 4-6 --from-unit=K --to=iec --format %.2f <<<"$line" | awk '{printf "%9sB", $6}')"
    item="  Type: ${type} Free: ${free} "
    ((${#item} + 2 > width)) && width=$((${#item} + 2))
    menu+=("$tag" "$item" "OFF")
  done < <(pvesm status -content "$content" | awk 'NR>1')
  case $((${#menu[@]} / 3)) in
  0)
    msg_error "No storage accepts ${label} content."
    exit 119
    ;;
  1) echo "${menu[0]}" ;;
  *)
    whiptail --backtitle "$PXH_BACKTITLE" --title "Storage pools" --radiolist \
      "Which storage should hold the ${label}?\n" 16 $((width + 23)) 6 "${menu[@]}" 3>&1 1>&2 2>&3
    ;;
  esac
}
