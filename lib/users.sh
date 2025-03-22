create_system_user() {
  local name="$1"
  local home="${2:-/var/lib/$name}"
  local group="${3:-$name}"
  id "$name" &>/dev/null && return 0
  if is_alpine; then
    addgroup -S "$group" 2>/dev/null || true
    adduser -S -D -H -G "$group" -h "$home" -s /sbin/nologin "$name"
  else
    getent group "$group" &>/dev/null || groupadd -r "$group"
    useradd -r -g "$group" -s /usr/sbin/nologin -d "$home" "$name"
  fi
}

remove_system_user() {
  local name="$1"
  local group="${2:-$name}"
  if is_alpine; then
    deluser "$name" 2>/dev/null || true
    delgroup "$group" 2>/dev/null || true
  else
    userdel "$name" 2>/dev/null || true
    groupdel "$group" 2>/dev/null || true
  fi
}

owned_dirs() {
  local owner="$1"
  shift
  mkdir -p "$@"
  chown -R "$owner" "$@"
}
