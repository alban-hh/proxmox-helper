PXH_SPINNER_PID=""
PXH_SPINNER_MSG=""

pxh_spinner_loop() {
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  local i=0
  while true; do
    printf "\r\033[2K%s %s" "${YWB}${frames[$((i++ % ${#frames[@]}))]}${CL}" "${YWB}${PXH_SPINNER_MSG}${CL}" >&2
    sleep 0.1
  done
}

stop_spinner() {
  if [[ -n "$PXH_SPINNER_PID" ]]; then
    kill "$PXH_SPINNER_PID" 2>/dev/null || true
    wait "$PXH_SPINNER_PID" 2>/dev/null || true
    PXH_SPINNER_PID=""
    printf "\r\033[2K" >&2
  fi
  stty sane 2>/dev/null || true
}

is_verbose() {
  [[ "${VERBOSE:-no}" == "yes" ]]
}

log_line() {
  local logfile="${PXH_LOG:-/tmp/proxmox-helper.log}"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$logfile" 2>/dev/null || true
}

msg_info() {
  local msg="$1"
  [[ -z "$msg" ]] && return 0
  stop_spinner
  log_line "[INFO] $msg"
  PXH_SPINNER_MSG="$msg"
  if is_verbose || [[ ! -t 2 ]]; then
    printf "\r\033[2K%s%s\n" "$HOURGLASS" "${YW}${msg}${CL}" >&2
    return 0
  fi
  pxh_spinner_loop &
  PXH_SPINNER_PID=$!
  disown "$PXH_SPINNER_PID" 2>/dev/null || true
}

msg_ok() {
  stop_spinner
  log_line "[OK] $1"
  echo -e "${CM}${GN}$1${CL}"
}

msg_error() {
  stop_spinner
  log_line "[ERROR] $1"
  echo -e "${BFR}${CROSS}${RD}$1${CL}" >&2
}

msg_warn() {
  stop_spinner
  log_line "[WARN] $1"
  echo -e "${BFR}${INFO}${YWB}$1${CL}" >&2
}

msg_note() {
  echo -e "${TAB}${BL}$1${CL}"
}

header_info() {
  clear 2>/dev/null || true
  echo -e "${BOLD}${BL}proxmox-helper${CL} ${DGN}·${CL} ${BOLD}${APP}${CL}"
  echo
}
