#!/usr/bin/env bash
APP="Netdata"
APP_SLUG="netdata"
DEFAULT_PORT=19999

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  require_pve_host
  get_local_ip
}

is_installed() {
  pkg_is_installed netdata
}

describe() {
  echo -e "${TAB}  - Netdata repository for this Debian release"
  echo -e "${TAB}  - Netdata agent on the Proxmox host"
}

repo_package_url() {
  local codename="$1"
  local base="https://repo.netdata.cloud/repos/repoconfig/debian/${codename}/"
  local pkg
  pkg="$(curl -fsSL "$base" | grep -oP 'netdata-repo_[^"]+all\.deb' | sort -V | tail -n1)"
  [[ -n "$pkg" ]] || return 1
  echo "${base}${pkg}"
}

install() {
  local codename url deb
  codename="$(detect_codename)"
  if [[ -z "$codename" ]]; then
    msg_error "Could not detect the Debian codename."
    exit 238
  fi

  msg_info "Setting up repository"
  ensure_packages debian-keyring curl
  url="$(repo_package_url "$codename")" || {
    msg_error "No netdata-repo package found for Debian ${codename}."
    exit 237
  }
  deb="$(mktemp --suffix=.deb)"
  curl_download "$deb" "$url"
  $STD dpkg -i "$deb"
  rm -f "$deb"
  msg_ok "Added repository"

  msg_info "Installing ${APP}"
  PXH_APT_UPDATED=""
  install_packages netdata
  msg_ok "Installed ${APP}"

  echo
  msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
}

update() {
  msg_info "Updating ${APP}"
  PXH_APT_UPDATED=""
  install_packages netdata
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  stop_service netdata
  remove_packages netdata netdata-repo
  rm -rf /var/log/netdata /var/lib/netdata /var/cache/netdata /etc/netdata
  rm -f /etc/apt/trusted.gpg.d/netdata-archive-keyring.gpg /etc/apt/sources.list.d/netdata.list
  $STD apt-get autoremove -y
  userdel netdata &>/dev/null || true
  systemctl daemon-reload
  msg_ok "Removed ${APP}"
}

run_addon "$@"
