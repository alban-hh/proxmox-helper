STD=""

silent() {
  local logfile="${PXH_LOG:-/tmp/proxmox-helper.log}"
  local restore_errexit=false
  [[ "$-" == *e* ]] && restore_errexit=true
  set +e
  "$@" >>"$logfile" 2>&1
  local rc=$?
  $restore_errexit && set -e
  if ((rc != 0)); then
    PXH_FAILED_CMD="$*"
    PXH_FAILED_LOG="$logfile"
    return "$rc"
  fi
}

set_std_mode() {
  if is_verbose; then
    STD=""
  else
    STD="silent"
  fi
}

explain_exit_code() {
  case "$1" in
  1) echo "General error" ;;
  6) echo "DNS resolution failed" ;;
  7) echo "Failed to connect to host" ;;
  22) echo "HTTP error returned by server" ;;
  28) echo "Network operation timed out" ;;
  100) echo "Package manager error" ;;
  104) echo "Not running as root" ;;
  106) echo "Unsupported architecture" ;;
  232) echo "Must run on the Proxmox VE host" ;;
  237) echo "Docker is not available" ;;
  238) echo "Unsupported operating system" ;;
  *) echo "Unknown error" ;;
  esac
}

error_handler() {
  local rc="${1:-$?}"
  local cmd="${2:-${BASH_COMMAND:-unknown}}"
  local line="${BASH_LINENO[0]:-?}"
  stop_spinner
  echo -e "\n${RD}[ERROR]${CL} exit code ${RD}${rc}${CL} ($(explain_exit_code "$rc")) on line ${RD}${line}${CL}" >&2
  echo -e "${RD}command:${CL} ${YWB}${PXH_FAILED_CMD:-$cmd}${CL}" >&2
  if [[ -n "${PXH_FAILED_LOG:-}" && -s "$PXH_FAILED_LOG" ]]; then
    echo -e "${RD}last log lines from ${PXH_FAILED_LOG}:${CL}" >&2
    tail -n 20 "$PXH_FAILED_LOG" >&2
  fi
  exit "$rc"
}

enable_error_handling() {
  set -Eeuo pipefail
  trap 'error_handler $? "$BASH_COMMAND"' ERR
}

root_check() {
  if [[ "$(id -u)" -ne 0 ]]; then
    msg_error "Run this script as root."
    exit 104
  fi
}

is_alpine() {
  [[ -f /etc/alpine-release ]]
}

on_pve_host() {
  command -v pveversion &>/dev/null
}

require_pve_host() {
  if ! on_pve_host; then
    msg_error "${APP:-This script} must run on the Proxmox VE host."
    exit 232
  fi
}

require_debian_like() {
  if is_alpine || ! command -v apt-get &>/dev/null; then
    msg_error "${APP:-This script} needs a Debian or Ubuntu based system."
    exit 238
  fi
}

arch_resolve() {
  local amd64_val="${1:-amd64}"
  local arm64_val="${2:-arm64}"
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
  case "$arch" in
  amd64 | x86_64) echo "$amd64_val" ;;
  arm64 | aarch64) echo "$arm64_val" ;;
  *)
    msg_error "Unsupported architecture: $arch"
    return 106
    ;;
  esac
}

detect_codename() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "${VERSION_CODENAME:-}"
  fi
}

confirm_not_pve_host() {
  on_pve_host || return 0
  msg_warn "${APP:-This script} is meant to run inside an LXC container, not on the Proxmox VE host."
  if ! confirm "Continue anyway?"; then
    msg_warn "Aborted."
    exit 0
  fi
}

random_alnum() {
  local length="${1:-32}"
  LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | head -c "$length"
}
