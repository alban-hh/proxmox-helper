#!/usr/bin/env bash
APP="Tailscale"
APP_SLUG="tailscale"

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd)" || PXH_ROOT=""
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

install_in_alpine() {
  local ctid="$1"
  pct exec "$ctid" -- sh -c '
set -e
if ! grep -q "^[^#].*community" /etc/apk/repositories; then
  echo "https://dl-cdn.alpinelinux.org/alpine/v$(cut -d. -f1,2 /etc/alpine-release)/community" >>/etc/apk/repositories
fi
apk update
apk add --no-cache tailscale
rc-update add tailscale default || true
rc-service tailscale start || true
'
}

install_in_debian() {
  local ctid="$1"
  pct exec "$ctid" -- bash -c '
set -e
export DEBIAN_FRONTEND=noninteractive
. /etc/os-release
if ! getent hosts pkgs.tailscale.com >/dev/null 2>&1; then
  cp /etc/resolv.conf /tmp/resolv.conf.backup
  echo "nameserver 1.1.1.1" >/etc/resolv.conf
fi
apt-get update -qq
apt-get install -y -qq curl gpg ca-certificates >/dev/null
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.tailscale.com/stable/${ID}/${VERSION_CODENAME}.noarmor.gpg" -o /etc/apt/keyrings/tailscale.gpg
printf "Types: deb\nURIs: https://pkgs.tailscale.com/stable/%s\nSuites: %s\nComponents: main\nSigned-By: /etc/apt/keyrings/tailscale.gpg\n" "$ID" "$VERSION_CODENAME" >/etc/apt/sources.list.d/tailscale.sources
rm -f /etc/apt/sources.list.d/tailscale.list
apt-get update -qq
apt-get install -y -qq tailscale >/dev/null
if [ -f /tmp/resolv.conf.backup ]; then
  mv /tmp/resolv.conf.backup /etc/resolv.conf
fi
'
}

main() {
  local ctid distro
  msg_note "Adds Tailscale to an existing LXC container."
  confirm "Proceed?" || exit 0

  ctid="$(select_container "Select the container that should get Tailscale:")" || exit 0
  [[ -n "$ctid" ]] || exit 0

  msg_info "Allowing /dev/net/tun in container ${ctid}"
  allow_tun_device "$ctid"
  msg_ok "Configured TUN access"

  ensure_container_running "$ctid"
  distro="$(container_distro "$ctid")"

  msg_info "Installing Tailscale in container ${ctid} (${distro})"
  if [[ "$distro" == "alpine" ]]; then
    $STD install_in_alpine "$ctid"
  else
    $STD install_in_debian "$ctid"
  fi
  add_container_tag "$ctid" "tailscale"
  msg_ok "Installed Tailscale in container ${ctid}"

  echo
  msg_warn "Reboot the container, then run 'tailscale up' inside it."
}

run_tool "$@"
