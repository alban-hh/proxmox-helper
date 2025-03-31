gh_api() {
  local url="$1"
  local output="$2"
  local headers=(-H 'Accept: application/vnd.github+json')
  [[ -n "${GITHUB_TOKEN:-}" ]] && headers+=(-H "Authorization: Bearer $GITHUB_TOKEN")
  local http_code
  http_code="$(curl -sSL --connect-timeout 10 --max-time 60 -w '%{http_code}' -o "$output" "${headers[@]}" "$url" 2>/dev/null || true)"
  case "$http_code" in
  200) return 0 ;;
  403)
    msg_error "GitHub API rate limit exceeded. Export GITHUB_TOKEN to raise the limit."
    return 22
    ;;
  000 | "")
    msg_error "GitHub API did not respond. Check network and DNS."
    return 7
    ;;
  *)
    msg_error "GitHub API request failed (HTTP ${http_code}) for ${url}"
    return 22
    ;;
  esac
}

gh_strip_v() {
  local tag="$1"
  if [[ "$tag" =~ ^v[0-9] ]]; then
    echo "${tag:1}"
  else
    echo "$tag"
  fi
}

gh_version_file() {
  echo "$HOME/.$(echo "${1,,}" | tr -d ' ')"
}

gh_installed_version() {
  local file
  file="$(gh_version_file "$1")"
  [[ -f "$file" ]] && gh_strip_v "$(<"$file")"
}

gh_latest_release_json() {
  local repo="$1"
  local version="${2:-latest}"
  local tmp
  tmp="$(mktemp)"
  local url="https://api.github.com/repos/${repo}/releases/latest"
  [[ "$version" != "latest" ]] && url="https://api.github.com/repos/${repo}/releases/tags/${version}"
  if ! gh_api "$url" "$tmp"; then
    rm -f "$tmp"
    return 22
  fi
  cat "$tmp"
  rm -f "$tmp"
}

gh_release_available() {
  local app="$1"
  local repo="$2"
  local pinned="${3:-}"
  local json latest current
  msg_info "Checking for update: ${app}"
  ensure_packages jq
  json="$(gh_latest_release_json "$repo" "${pinned:-latest}")" || return 22
  latest="$(gh_strip_v "$(jq -r '.tag_name // empty' <<<"$json")")"
  if [[ -z "$latest" ]]; then
    msg_error "No release found for ${repo}"
    return 250
  fi
  current="$(gh_installed_version "$app")"
  if [[ "$current" != "$latest" ]]; then
    RELEASE_TAG="$(jq -r '.tag_name' <<<"$json")"
    RELEASE_VERSION="$latest"
    msg_ok "Update available: ${app} ${current:-not installed} -> ${latest}"
    return 0
  fi
  msg_ok "${app} is already on the latest version (${current})"
  return 1
}

gh_pick_asset() {
  local json="$1"
  local pattern="$2"
  local url name
  while IFS= read -r url; do
    name="${url##*/}"
    case "$name" in
    $pattern)
      echo "$url"
      return 0
      ;;
    esac
  done < <(jq -r '.assets[].browser_download_url' <<<"$json")
  return 1
}

gh_pick_deb() {
  local json="$1"
  local pattern="${2:-}"
  local arch url
  arch="$(arch_resolve)"
  if [[ -n "$pattern" ]] && url="$(gh_pick_asset "$json" "$pattern")"; then
    echo "$url"
    return 0
  fi
  while IFS= read -r url; do
    [[ "$url" == *.deb ]] || continue
    if [[ "$url" =~ ${arch} || ("$arch" == "amd64" && "$url" =~ x86_64) || ("$arch" == "arm64" && "$url" =~ aarch64) ]]; then
      echo "$url"
      return 0
    fi
  done < <(jq -r '.assets[].browser_download_url' <<<"$json")
  while IFS= read -r url; do
    [[ "$url" == *.deb ]] && echo "$url" && return 0
  done < <(jq -r '.assets[].browser_download_url' <<<"$json")
  return 1
}

extract_archive() {
  local archive="$1"
  local workdir="$2"
  case "${archive##*/}" in
  *.zip)
    ensure_packages unzip
    unzip -q "$archive" -d "$workdir"
    ;;
  *.tar.* | *.tgz | *.txz)
    tar --no-same-owner -xf "$archive" -C "$workdir"
    ;;
  *)
    msg_error "Unsupported archive format: ${archive##*/}"
    return 65
    ;;
  esac
}

copy_unpacked() {
  local workdir="$1"
  local target="$2"
  local entries source_dir
  entries="$(find "$workdir" -mindepth 1 -maxdepth 1)"
  if [[ "$(wc -l <<<"$entries")" -eq 1 && -d "$entries" ]]; then
    source_dir="$entries"
  else
    source_dir="$workdir"
  fi
  mkdir -p "$target"
  if [[ "${CLEAN_INSTALL:-0}" == "1" ]]; then
    find "${target:?}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  fi
  shopt -s dotglob nullglob
  cp -r "$source_dir"/* "$target/"
  shopt -u dotglob nullglob
}

fetch_gh_release() {
  local app="$1"
  local repo="$2"
  local mode="${3:-tarball}"
  local version="${4:-latest}"
  local target="${5:-/opt/$app}"
  local pattern="${6:-}"
  local json tag url filename tmpdir workdir current

  ensure_packages jq
  json="$(gh_latest_release_json "$repo" "$version")" || return 22
  tag="$(jq -r '.tag_name // empty' <<<"$json")"
  version="$(gh_strip_v "$tag")"
  current="$(gh_installed_version "$app")"
  if [[ -n "$current" && "$current" == "$version" ]]; then
    msg_ok "${app} ${version} is already deployed"
    return 0
  fi

  tmpdir="$(mktemp -d)"
  workdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir" "$workdir"; trap - RETURN' RETURN
  msg_info "Fetching ${app} ${version}"

  case "$mode" in
  tarball)
    url="https://github.com/${repo}/archive/refs/tags/${tag}.tar.gz"
    filename="${tmpdir}/source.tar.gz"
    curl_download "$filename" "$url" || return 7
    extract_archive "$filename" "$workdir" || return 251
    copy_unpacked "$workdir" "$target"
    ;;
  binary)
    url="$(gh_pick_deb "$json" "$pattern")" || {
      msg_error "No .deb asset found for ${app}"
      return 252
    }
    filename="${tmpdir}/${url##*/}"
    curl_download "$filename" "$url" || return 7
    DEBIAN_FRONTEND=noninteractive SYSTEMD_OFFLINE=1 $STD apt-get install -y "$filename" || SYSTEMD_OFFLINE=1 $STD dpkg -i "$filename"
    ;;
  prebuild)
    url="$(gh_pick_asset "$json" "$pattern")" || {
      msg_error "No asset matching '${pattern}' for ${app}"
      return 252
    }
    filename="${tmpdir}/${url##*/}"
    curl_download "$filename" "$url" || return 7
    extract_archive "$filename" "$workdir" || return 251
    copy_unpacked "$workdir" "$target"
    ;;
  singlefile)
    url="$(gh_pick_asset "$json" "$pattern")" || {
      msg_error "No asset matching '${pattern}' for ${app}"
      return 252
    }
    mkdir -p "$target"
    curl_download "${target}/${app}" "$url" || return 7
    [[ "$app" != *.jar ]] && chmod +x "${target}/${app}"
    ;;
  *)
    msg_error "Unknown release mode: ${mode}"
    return 65
    ;;
  esac

  echo "$version" >"$(gh_version_file "$app")"
  msg_ok "Deployed ${app} ${version}"
}

gh_latest_tag() {
  local repo="$1"
  local json
  json="$(gh_latest_release_json "$repo")" || return 22
  jq -r '.tag_name // empty' <<<"$json"
}
