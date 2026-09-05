#!/usr/bin/env bash
APP="NetBird"
APP_SLUG="netbird"

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd)" || PXH_ROOT=""
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

install_in_container() {
  local ctid="$1"
  pct exec "$ctid" -- bash -c '
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates gpg >/dev/null
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.netbird.io/debian/public.key | gpg --dearmor --yes -o /etc/apt/keyrings/netbird.gpg
printf "Types: deb\nURIs: https://pkgs.netbird.io/debian\nSuites: stable\nComponents: main\nSigned-By: /etc/apt/keyrings/netbird.gpg\n" >/etc/apt/sources.list.d/netbird.sources
rm -f /etc/apt/sources.list.d/netbird.list
apt-get update -qq
apt-get install -y -qq netbird >/dev/null
if systemctl list-unit-files docker.service >/dev/null 2>&1; then
  mkdir -p /etc/systemd/system/netbird.service.d
  printf "[Unit]\nAfter=docker.service\nWants=docker.service\n" >/etc/systemd/system/netbird.service.d/after-docker.conf
  systemctl daemon-reload
fi
'
}

main() {
  local ctid distro
  msg_note "Adds NetBird to an existing Debian or Ubuntu LXC container."
  confirm "Proceed?" || exit 0

  ctid="$(select_container "Select the container that should get NetBird:")" || exit 0
  [[ -n "$ctid" ]] || exit 0

  ensure_container_running "$ctid"
  distro="$(container_distro "$ctid")"
  if [[ "$distro" != "debian" && "$distro" != "ubuntu" ]]; then
    msg_error "Only Debian and Ubuntu containers are supported. Detected: ${distro}"
    exit 238
  fi

  msg_info "Allowing /dev/net/tun in container ${ctid}"
  allow_tun_device "$ctid"
  msg_ok "Configured TUN access"

  msg_info "Installing NetBird in container ${ctid}"
  $STD install_in_container "$ctid"
  add_container_tag "$ctid" "netbird"
  msg_ok "Installed NetBird in container ${ctid}"

  echo
  msg_warn "Reboot the container, then run 'netbird up' inside it."
}

run_tool "$@"
