PXH_APT_UPDATED=""

apt_update_once() {
  [[ -n "$PXH_APT_UPDATED" ]] && return 0
  $STD apt-get update
  PXH_APT_UPDATED=1
}

pkg_is_installed() {
  if is_alpine; then
    apk info -e "$1" &>/dev/null
  else
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
  fi
}

ensure_packages() {
  local missing=()
  local pkg
  for pkg in "$@"; do
    command -v "$pkg" &>/dev/null && continue
    pkg_is_installed "$pkg" && continue
    missing+=("$pkg")
  done
  ((${#missing[@]} == 0)) && return 0
  if is_alpine; then
    $STD apk add --no-cache "${missing[@]}"
  else
    apt_update_once
    DEBIAN_FRONTEND=noninteractive $STD apt-get install -y "${missing[@]}"
  fi
}

install_packages() {
  if is_alpine; then
    $STD apk add --no-cache "$@"
  else
    apt_update_once
    DEBIAN_FRONTEND=noninteractive $STD apt-get install -y "$@"
  fi
}

remove_packages() {
  if is_alpine; then
    $STD apk del "$@"
  else
    DEBIAN_FRONTEND=noninteractive $STD apt-get purge -y "$@"
  fi
}

setup_deb822_repo() {
  local name="$1"
  local gpg_url="$2"
  local repo_url="$3"
  local suite="$4"
  local component="${5:-main}"
  local architectures="${6:-}"
  local keyring="/etc/apt/keyrings/${name}.gpg"
  local tmp_gpg

  mkdir -p /etc/apt/keyrings
  rm -f "/etc/apt/sources.list.d/${name}.list" "/etc/apt/sources.list.d/${name}.sources"
  tmp_gpg="$(mktemp)"
  curl -fsSL "$gpg_url" -o "$tmp_gpg" || {
    msg_error "Failed to download GPG key for ${name}"
    rm -f "$tmp_gpg"
    return 7
  }
  if grep -q "BEGIN PGP" "$tmp_gpg"; then
    gpg --dearmor --yes -o "$keyring" <"$tmp_gpg"
  else
    cp -f "$tmp_gpg" "$keyring"
  fi
  rm -f "$tmp_gpg"
  chmod 644 "$keyring"

  {
    echo "Types: deb"
    echo "URIs: $repo_url"
    echo "Suites: $suite"
    [[ "$suite" != */ && -n "$component" ]] && echo "Components: $component"
    [[ -n "$architectures" ]] && echo "Architectures: $architectures"
    echo "Signed-By: $keyring"
  } >"/etc/apt/sources.list.d/${name}.sources"

  PXH_APT_UPDATED=""
  apt_update_once
}
