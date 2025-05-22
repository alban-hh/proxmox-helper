#!/usr/bin/env bash
APP="phpMyAdmin"
APP_SLUG="phpmyadmin"
RELEASE_REPO="phpmyadmin/phpmyadmin"
FALLBACK_VERSION="5.2.2"
INSTALL_DIR=""

command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y -qq curl; } &>/dev/null || apk add --no-cache curl &>/dev/null
PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")/.." 2>/dev/null && pwd || true)"
if [[ -f "${PXH_ROOT}/lib/bootstrap.sh" ]]; then . "${PXH_ROOT}/lib/bootstrap.sh"; else . <(curl -fsSL "${PXH_REPO}/lib/bootstrap.sh"); fi

prepare() {
  get_local_ip
  if is_alpine; then
    INSTALL_DIR="/usr/share/phpmyadmin"
  else
    INSTALL_DIR="/var/www/html/phpMyAdmin"
  fi
}

is_installed() {
  if is_alpine; then
    [[ -d "$INSTALL_DIR" ]]
  else
    [[ -f "${INSTALL_DIR}/config.inc.php" ]]
  fi
}

describe() {
  if is_alpine; then
    echo -e "${TAB}  - Lighttpd, PHP and PHP-FPM"
  else
    echo -e "${TAB}  - PHP modules for the existing Apache setup"
  fi
  echo -e "${TAB}  - phpMyAdmin in ${INSTALL_DIR}"
}

latest_version() {
  local tag
  tag="$(gh_latest_tag "$RELEASE_REPO" 2>/dev/null || true)"
  tag="${tag#RELEASE_}"
  tag="${tag//_/.}"
  echo "${tag:-$FALLBACK_VERSION}"
}

install_php() {
  msg_info "Installing PHP"
  if is_alpine; then
    ensure_packages lighttpd php php-fpm php-session php-json php-mysqli curl tar openssl
  else
    ensure_packages php php-mysqli php-mbstring php-zip php-gd php-json php-curl
  fi
  msg_ok "Installed PHP"
}

download_release() {
  local version tarball
  version="$(latest_version)"
  msg_info "Downloading phpMyAdmin ${version}"
  tarball="$(mktemp)"
  curl_download "$tarball" "https://files.phpmyadmin.net/phpMyAdmin/${version}/phpMyAdmin-${version}-all-languages.tar.gz" || {
    msg_error "Download failed for phpMyAdmin ${version}"
    exit 115
  }
  mkdir -p "$INSTALL_DIR"
  tar xf "$tarball" --strip-components=1 -C "$INSTALL_DIR"
  rm -f "$tarball"
  msg_ok "Extracted phpMyAdmin ${version}"
}

configure_debian() {
  if [[ ! -f "${INSTALL_DIR}/config.inc.php" ]]; then
    cp "${INSTALL_DIR}/config.sample.inc.php" "${INSTALL_DIR}/config.inc.php"
    sed -i "s#\$cfg\['blowfish_secret'\] = '';#\$cfg['blowfish_secret'] = '$(random_alnum 32)';#" "${INSTALL_DIR}/config.inc.php"
  fi
  chmod 660 "${INSTALL_DIR}/config.inc.php"
  chown -R www-data:www-data "$INSTALL_DIR"
  restart_service apache2
}

configure_alpine() {
  local php_fpm
  mkdir -p /etc/lighttpd
  cat >/etc/lighttpd/lighttpd.conf <<CONFIG
server.modules = (
  "mod_access",
  "mod_alias",
  "mod_accesslog",
  "mod_fastcgi"
)
server.document-root = "${INSTALL_DIR}"
server.port = 80
index-file.names = ( "index.php", "index.html" )
fastcgi.server = ( ".php" =>
  ((
    "host" => "127.0.0.1",
    "port" => 9000,
    "check-local" => "disable"
  ))
)
alias.url = ( "/phpMyAdmin/" => "${INSTALL_DIR}/" )
accesslog.filename = "/var/log/lighttpd/access.log"
server.errorlog = "/var/log/lighttpd/error.log"
CONFIG
  php_fpm="php-fpm$(php -r 'echo PHP_MAJOR_VERSION . PHP_MINOR_VERSION;')"
  enable_service "$php_fpm"
  enable_service lighttpd
}

configure() {
  msg_info "Configuring web server"
  if is_alpine; then
    configure_alpine
  else
    configure_debian
  fi
  msg_ok "Configured web server"
}

install() {
  check_internet
  install_php
  download_release
  configure
  echo
  if is_alpine; then
    msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}/${CL}"
  else
    msg_ok "${APP} is reachable at ${BL}http://${LOCAL_IP}/phpMyAdmin${CL}"
  fi
}

update() {
  check_internet
  create_backup "${INSTALL_DIR}/config.inc.php" "${INSTALL_DIR}/upload" "${INSTALL_DIR}/save" "${INSTALL_DIR}/tmp" "${INSTALL_DIR}/themes"
  download_release
  restore_backup
  configure
  msg_ok "Updated ${APP}"
}

uninstall() {
  msg_info "Uninstalling ${APP}"
  rm -rf "$INSTALL_DIR"
  if is_alpine; then
    rm -f /etc/lighttpd/lighttpd.conf
    restart_service lighttpd
  else
    restart_service apache2
  fi
  msg_ok "Removed ${APP}"
}

run_addon "$@"
