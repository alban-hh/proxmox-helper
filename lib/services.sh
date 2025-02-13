write_systemd_unit() {
  local name="$1"
  local content="$2"
  printf '%s\n' "$content" >"/etc/systemd/system/${name}.service"
  $STD systemctl daemon-reload
}

enable_service() {
  local name="$1"
  $STD systemctl enable --now "$name"
}

restart_service() {
  local name="$1"
  $STD systemctl restart "$name"
}

stop_service() {
  local name="$1"
  systemctl stop "$name" 2>/dev/null || true
}

remove_service() {
  local name="$1"
  systemctl disable --now "$name" 2>/dev/null || true
  rm -f "/etc/systemd/system/${name}.service"
  $STD systemctl daemon-reload
}

service_is_active() {
  systemctl is-active --quiet "$1"
}

persist_usr_local_bin() {
  on_pve_host && return 0
  local profile="/etc/profile.d/proxmox-helper-path.sh"
  if [[ ! -f "$profile" ]]; then
    echo 'export PATH="/usr/local/bin:$PATH"' >"$profile"
    chmod +x "$profile"
  fi
  if [[ -f /root/.bashrc ]] && ! grep -q '/usr/local/bin' /root/.bashrc; then
    echo 'export PATH="/usr/local/bin:$PATH"' >>/root/.bashrc
  fi
}

ensure_update_script() {
  local slug="${1:-$APP_SLUG}"
  local script="/usr/local/bin/update_${slug//-/_}"
  [[ -f "$script" ]] && return 0
  msg_info "Creating update script"
  cat >"$script" <<UPDATER
#!/usr/bin/env bash
bash -c "\$(curl -fsSL ${PXH_REPO}/addons/${slug}.sh)" -- --update
UPDATER
  chmod +x "$script"
  msg_ok "Created ${script}"
}

remove_update_script() {
  local slug="${1:-$APP_SLUG}"
  rm -f "/usr/local/bin/update_${slug//-/_}"
}
