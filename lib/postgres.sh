pg_run() {
  sudo -u postgres psql "$@"
}

pg_database_exists() {
  pg_run -lqt 2>/dev/null | cut -d '|' -f1 | grep -qw "$1"
}

pg_role_exists() {
  pg_run -tAc "SELECT 1 FROM pg_roles WHERE rolname='$1'" 2>/dev/null | grep -q 1
}

pg_allow_local_password_auth() {
  local db="$1"
  local user="$2"
  local hba
  hba="$(pg_run -tAc "SHOW hba_file;" 2>/dev/null | tr -d ' ')"
  [[ -n "$hba" && -f "$hba" ]] || return 0
  grep -qE "^host\s+${db}\s+${user}\s+127.0.0.1" "$hba" && return 0
  sed -i "/^# IPv4 local connections:/a host    ${db}    ${user}    127.0.0.1/32    scram-sha-256" "$hba"
  sed -i "/^# IPv4 local connections:/a host    ${db}    ${user}    ::1/128         scram-sha-256" "$hba"
  $STD systemctl reload postgresql
}

pg_create_database() {
  local db="$1"
  local user="$2"
  local password="$3"
  if pg_role_exists "$user"; then
    $STD pg_run -c "ALTER USER ${user} WITH PASSWORD '${password}';"
  else
    $STD pg_run -c "CREATE USER ${user} WITH PASSWORD '${password}';"
  fi
  $STD pg_run -c "CREATE DATABASE ${db} WITH OWNER ${user} ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0;"
  $STD pg_run -c "GRANT ALL PRIVILEGES ON DATABASE ${db} TO ${user};"
  $STD pg_run -d "$db" -c "GRANT ALL ON SCHEMA public TO ${user};" || true
  pg_allow_local_password_auth "$db" "$user"
}

pg_drop_database() {
  local db="$1"
  local user="$2"
  command -v psql &>/dev/null || return 0
  $STD pg_run -c "DROP DATABASE IF EXISTS ${db};" || true
  $STD pg_run -c "DROP USER IF EXISTS ${user};" || true
}
