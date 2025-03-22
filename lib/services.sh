PXH_STATE_DIR="/usr/local/proxmox-helper"

ensure_state_dir() {
  mkdir -p "$PXH_STATE_DIR"
  chmod 755 "$PXH_STATE_DIR"
}

install_systemd_service() {
  local name="$1"
  local content="$2"
  printf '%s\n' "$content" >"/etc/systemd/system/${name}.service"
  $STD systemctl daemon-reload
}

install_openrc_service() {
  local name="$1"
  local content="$2"
  printf '#!/sbin/openrc-run\n%s\n' "$content" >"/etc/init.d/${name}"
  chmod +x "/etc/init.d/${name}"
}

enable_service() {
  local name="$1"
  if is_alpine; then
    $STD rc-update add "$name" default
    $STD rc-service "$name" start
  else
    $STD systemctl enable --now "$name"
  fi
}

start_service() {
  local name="$1"
  if is_alpine; then
    $STD rc-service "$name" start
  else
    $STD systemctl start "$name"
  fi
}

stop_service() {
  local name="$1"
  if is_alpine; then
    rc-service "$name" stop &>/dev/null || true
  else
    systemctl stop "$name" &>/dev/null || true
  fi
}

restart_service() {
  local name="$1"
  if is_alpine; then
    $STD rc-service "$name" restart
  else
    $STD systemctl restart "$name"
  fi
}

remove_service() {
  local name="$1"
  if is_alpine; then
    rc-service "$name" stop &>/dev/null || true
    rc-update del "$name" &>/dev/null || true
    rm -f "/etc/init.d/${name}"
  else
    systemctl disable --now "$name" &>/dev/null || true
    rm -f "/etc/systemd/system/${name}.service"
    systemctl daemon-reload &>/dev/null || true
  fi
}

service_is_active() {
  if is_alpine; then
    rc-service "$1" status &>/dev/null
  else
    systemctl is-active --quiet "$1"
  fi
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
  persist_usr_local_bin
  msg_ok "Created ${script}"
}

remove_update_script() {
  local slug="${1:-$APP_SLUG}"
  rm -f "/usr/local/bin/update_${slug//-/_}"
}
