addon_has() {
  declare -f "$1" &>/dev/null
}

addon_prepare() {
  addon_has prepare && prepare
  return 0
}

addon_run_install() {
  if is_installed; then
    msg_warn "${APP} is already installed."
    exit 0
  fi
  install
}

addon_run_update() {
  if ! is_installed; then
    msg_error "${APP} is not installed. Nothing to update."
    exit 233
  fi
  if ! addon_has update; then
    msg_error "${APP} does not support in-place updates."
    exit 1
  fi
  update
  addon_has APP_SLUG || ensure_update_script
}

addon_run_uninstall() {
  if ! is_installed; then
    msg_warn "${APP} is not installed."
    exit 0
  fi
  if ! addon_has uninstall; then
    msg_error "${APP} does not support automated removal."
    exit 1
  fi
  uninstall
}

addon_interactive() {
  if is_installed; then
    msg_warn "${APP} is already installed."
    echo
    if addon_has uninstall && confirm "Uninstall ${APP}?"; then
      uninstall
      exit 0
    fi
    if addon_has update && confirm "Update ${APP}?"; then
      update
      ensure_update_script
      exit 0
    fi
    msg_warn "No action selected."
    exit 0
  fi

  msg_warn "${APP} is not installed."
  echo
  if addon_has describe; then
    echo -e "${TAB}${INFO}This will install:"
    describe
    echo
  fi
  if confirm "Install ${APP}?"; then
    install
  else
    msg_warn "Installation cancelled."
  fi
}

addon_usage() {
  echo "Usage: ${APP_SLUG}.sh [--install | --update | --uninstall]"
  echo
  echo "Without arguments the script runs interactively."
}

run_addon() {
  local action="${1:-}"
  [[ "${type:-}" == "update" ]] && action="--update"
  root_check
  header_info
  addon_prepare
  case "$action" in
  "") addon_interactive ;;
  --install | install) addon_run_install ;;
  --update | update) addon_run_update ;;
  --uninstall | uninstall) addon_run_uninstall ;;
  -h | --help) addon_usage ;;
  *)
    addon_usage
    exit 64
    ;;
  esac
}

run_tool() {
  root_check
  header_info
  require_pve_host
  main "$@"
}
