setup_nodejs() {
  local version="${NODE_VERSION:-22}"
  local major="${version%%.*}"
  local modules="${NODE_MODULE:-}"
  local current=""

  if command -v node &>/dev/null; then
    current="$(node -v | tr -d 'v' | cut -d. -f1)"
  fi
  if [[ "$current" != "$major" ]]; then
    msg_info "Installing Node.js ${major}"
    ensure_packages ca-certificates curl gpg
    setup_deb822_repo "nodesource" "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" "https://deb.nodesource.com/node_${major}.x" "nodistro" "main"
    install_packages nodejs
    msg_ok "Installed Node.js $(node -v)"
  else
    msg_ok "Node.js $(node -v) already present"
  fi

  if [[ -n "$modules" ]]; then
    msg_info "Installing global npm modules"
    IFS=',' read -ra module_list <<<"$modules"
    $STD npm install -g "${module_list[@]}"
    msg_ok "Installed ${modules}"
  fi
}

setup_uv() {
  local python_version="${PYTHON_VERSION:-}"
  local arch

  if ! command -v uv &>/dev/null; then
    msg_info "Installing uv"
    arch="$(arch_resolve x86_64 aarch64)"
    fetch_gh_release "uv" "astral-sh/uv" "prebuild" "latest" "/usr/local/bin" "uv-${arch}-unknown-linux-gnu.tar.gz"
    persist_usr_local_bin
  else
    msg_ok "uv $(uv --version | awk '{print $2}') already present"
  fi

  if [[ -n "$python_version" ]]; then
    msg_info "Installing Python ${python_version} via uv"
    $STD uv python install "$python_version"
    msg_ok "Installed Python ${python_version}"
  fi
}

setup_go() {
  local requested="${GO_VERSION:-latest}"
  local arch version

  arch="$(arch_resolve)"
  if [[ "$requested" == "latest" ]]; then
    version="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1 | sed 's/^go//')"
  else
    version="$requested"
  fi

  if command -v go &>/dev/null && [[ "$(go version | awk '{print $3}')" == "go${version}" ]]; then
    msg_ok "Go ${version} already present"
    return 0
  fi

  msg_info "Installing Go ${version}"
  rm -rf /usr/local/go
  curl_download "/tmp/go.tar.gz" "https://go.dev/dl/go${version}.linux-${arch}.tar.gz"
  tar -C /usr/local -xzf /tmp/go.tar.gz
  rm -f /tmp/go.tar.gz
  ln -sf /usr/local/go/bin/go /usr/local/bin/go
  ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
  persist_usr_local_bin
  msg_ok "Installed Go ${version}"
}

setup_postgresql() {
  local version="${PG_VERSION:-16}"
  local codename

  if command -v psql &>/dev/null && [[ "$(psql -V | awk '{print $3}' | cut -d. -f1)" == "$version" ]]; then
    msg_ok "PostgreSQL ${version} already present"
    return 0
  fi

  msg_info "Installing PostgreSQL ${version}"
  ensure_packages ca-certificates curl gpg
  codename="$(detect_codename)"
  setup_deb822_repo "pgdg" "https://www.postgresql.org/media/keys/ACCC4CF8.asc" "https://apt.postgresql.org/pub/repos/apt" "${codename}-pgdg" "main"
  install_packages "postgresql-${version}" "postgresql-client-${version}"
  $STD systemctl enable --now postgresql
  msg_ok "Installed PostgreSQL ${version}"
}
