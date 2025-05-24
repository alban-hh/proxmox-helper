#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="${PXH_GIT_URL:-https://github.com/alban-hh/proxmox-helper.git}"
INSTALL_DIR="${PXH_INSTALL_DIR:-/opt/proxmox-helper}"
BIN_LINK="/usr/local/bin/pxh"

need_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root." >&2
    exit 104
  fi
}

ensure_git() {
  command -v git &>/dev/null && return 0
  if command -v apt-get &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq git >/dev/null
  elif command -v apk &>/dev/null; then
    apk add --no-cache git >/dev/null
  else
    echo "git is required." >&2
    exit 1
  fi
}

clone_or_pull() {
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    git -C "$INSTALL_DIR" pull --ff-only -q
    echo "Updated ${INSTALL_DIR}"
  else
    git clone -q --depth 1 "$REPO_URL" "$INSTALL_DIR"
    echo "Cloned into ${INSTALL_DIR}"
  fi
}

link_launcher() {
  ln -sf "${INSTALL_DIR}/bin/pxh" "$BIN_LINK"
  chmod +x "${INSTALL_DIR}/bin/pxh" "${INSTALL_DIR}"/addons/*.sh
  echo "Linked ${BIN_LINK}"
}

main() {
  need_root
  ensure_git
  clone_or_pull
  link_launcher
  echo
  echo "Try: pxh list"
}

main "$@"
