#!/usr/bin/env bash
APP="Homebrew"
APP_SLUG="homebrew"
INSTALL_PATH="/home/linuxbrew/.linuxbrew"
BREW_GROUP="linuxbrew"
BREW_USER=""

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd)" || PXH_ROOT=""
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  require_debian_like
}

is_installed() {
  [[ -d "$INSTALL_PATH" ]]
}

describe() {
  echo -e "${TAB}  - Homebrew (Linuxbrew) under ${INSTALL_PATH}"
  echo -e "${TAB}  - Shell integration for a non-root user"
}

first_regular_user() {
  awk -F: '$3 >= 1000 && $3 < 65534 { print $1; exit }' /etc/passwd
}

pick_brew_user() {
  BREW_USER="$(first_regular_user)"
  if [[ -n "$BREW_USER" ]]; then
    msg_ok "Using user ${BREW_USER}"
    return 0
  fi
  msg_warn "Homebrew refuses to run as root and no regular user exists."
  if ! confirm "Create a 'brew' user?"; then
    msg_error "Cannot continue without a non-root user."
    exit 254
  fi
  useradd -m -s /bin/bash brew
  BREW_USER="brew"
  msg_ok "Created user brew"
}

shell_snippet() {
  printf 'if [ -d "%s" ]; then\n  eval ""\nfi\n' "$INSTALL_PATH" "$INSTALL_PATH"
}

configure_shell() {
  local home rc
  shell_snippet >/etc/profile.d/homebrew.sh
  chmod +x /etc/profile.d/homebrew.sh
  home="$(getent passwd "$BREW_USER" | cut -d: -f6)"
  for rc in "${home}/.bashrc" "${home}/.profile"; do
    grep -q 'linuxbrew' "$rc" 2>/dev/null && continue
    shell_snippet >>"$rc"
  done
}

install() {
  pick_brew_user

  msg_info "Installing dependencies"
  ensure_packages build-essential git file procps curl
  msg_ok "Installed dependencies"

  msg_info "Preparing prefix"
  export PATH="/usr/sbin:$PATH"
  groupadd -f "$BREW_GROUP"
  mkdir -p "$INSTALL_PATH"
  chown -R "${BREW_USER}:${BREW_GROUP}" /home/linuxbrew
  chmod 2775 /home/linuxbrew "$INSTALL_PATH"
  usermod -aG "$BREW_GROUP" "$BREW_USER"
  msg_ok "Prepared ${INSTALL_PATH}"

  msg_info "Running the Homebrew installer as ${BREW_USER}"
  $STD su - "$BREW_USER" -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  msg_ok "Installed Homebrew"

  msg_info "Configuring shell integration"
  configure_shell
  msg_ok "Configured shell integration"

  msg_info "Verifying"
  $STD su - "$BREW_USER" -c "eval \"\$(${INSTALL_PATH}/bin/brew shellenv)\" && brew --version"
  msg_ok "Homebrew works for ${BREW_USER}"

  echo
  msg_note "Switch with: su - ${BREW_USER}"
  msg_note "Then: brew install <package>"
}

update() {
  BREW_USER="$(first_regular_user)"
  msg_info "Updating Homebrew"
  $STD su - "$BREW_USER" -c "eval \"\$(${INSTALL_PATH}/bin/brew shellenv)\" && brew update && brew upgrade"
  msg_ok "Updated Homebrew"
}

uninstall() {
  local home rc
  msg_info "Uninstalling Homebrew"
  BREW_USER="$(first_regular_user)"
  if [[ -n "$BREW_USER" ]]; then
    home="$(getent passwd "$BREW_USER" | cut -d: -f6)"
    for rc in "${home}/.bashrc" "${home}/.profile"; do
      [[ -f "$rc" ]] && sed -i '/linuxbrew/,/^fi$/d' "$rc"
    done
  fi
  rm -rf /home/linuxbrew
  rm -f /etc/profile.d/homebrew.sh
  groupdel "$BREW_GROUP" &>/dev/null || true
  msg_ok "Removed Homebrew"
}

run_addon "$@"
