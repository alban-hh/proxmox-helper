create_backup() {
  local store="${BACKUP_DIR:-/opt/${APP_SLUG:-app}.backup}"
  local manifest="${store}/.manifest"
  local path dest

  (($# == 0)) && return 0
  mkdir -p "$store"
  touch "$manifest"

  msg_info "Backing up data"
  for path in "$@"; do
    path="${path%/}"
    grep -qxF "$path" "$manifest" 2>/dev/null && continue
    if [[ ! -e "$path" ]]; then
      msg_warn "Skipping backup of ${path} (not found)"
      continue
    fi
    if mountpoint -q "$path" 2>/dev/null; then
      msg_warn "Skipping backup of ${path} (mount point)"
      continue
    fi
    dest="${store}/files${path}"
    mkdir -p "$(dirname "$dest")"
    cp -a "$path" "$dest" || {
      msg_error "Backup of ${path} failed, aborting"
      exit 1
    }
    echo "$path" >>"$manifest"
  done
  msg_ok "Backed up data to ${store}"
}
