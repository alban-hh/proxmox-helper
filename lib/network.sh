get_local_ip() {
  local ip=""
  if [[ -f /run/local-ip.env ]]; then
    . /run/local-ip.env
  fi
  if [[ -n "${LOCAL_IP:-}" ]]; then
    export LOCAL_IP
    return 0
  fi
  ip="$(ip -4 addr show eth0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)"
  if [[ -z "$ip" ]] && command -v hostname &>/dev/null; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  if [[ -z "$ip" ]]; then
    ip="$(ip route get 1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") print $(i + 1)}')"
  fi
  if [[ -z "$ip" ]]; then
    ip="$(ip -6 addr show eth0 scope global 2>/dev/null | awk '/inet6 / {print $2}' | cut -d/ -f1 | head -n1)"
  fi
  if [[ -z "$ip" ]]; then
    msg_error "Could not determine the local IP address."
    return 6
  fi
  LOCAL_IP="$ip"
  export LOCAL_IP
}

check_internet() {
  if ! getent hosts github.com &>/dev/null; then
    msg_error "No internet connectivity (DNS lookup for github.com failed)."
    exit 6
  fi
}

curl_download() {
  local output="$1"
  local url="$2"
  local attempt=1
  while ((attempt <= 3)); do
    if curl --connect-timeout 15 --speed-limit 1024 --speed-time 60 -fsSL -o "$output" "$url"; then
      return 0
    fi
    ((attempt < 3)) && msg_warn "Download failed (attempt ${attempt}/3), retrying"
    ((attempt++))
  done
  return 7
}
