#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  echo "Usage: scripts/new-addon.sh <slug> \"<Display Name>\""
  echo
  echo "Creates addons/<slug>.sh from templates/addon.sh."
}

main() {
  local slug="${1:-}"
  local name="${2:-}"
  local target
  if [[ -z "$slug" || -z "$name" ]]; then
    usage
    exit 64
  fi
  if [[ ! "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "Slug must be lowercase letters, digits and dashes." >&2
    exit 64
  fi
  target="${ROOT}/addons/${slug}.sh"
  if [[ -e "$target" ]]; then
    echo "${target} already exists." >&2
    exit 1
  fi
  sed -e "s/__APP_NAME__/${name}/g" -e "s/__APP_SLUG__/${slug}/g" "${ROOT}/templates/addon.sh" >"$target"
  chmod +x "$target"
  echo "Created ${target}"
}

main "$@"
