confirm() {
  local question="$1"
  local answer
  echo -n "${TAB}${question} (y/N): "
  read -r answer
  [[ "${answer,,}" =~ ^(y|yes)$ ]]
}

ask() {
  local question="$1"
  local default="${2:-}"
  local answer
  if [[ -n "$default" ]]; then
    echo -n "${TAB}${question} [${default}]: "
  else
    echo -n "${TAB}${question}: "
  fi
  read -r answer
  echo "${answer:-$default}"
}

ask_required() {
  local question="$1"
  local answer=""
  while [[ -z "$answer" ]]; do
    echo -n "${TAB}${question}: "
    read -r answer
  done
  echo "$answer"
}

ask_secret() {
  local question="$1"
  local answer
  echo -n "${TAB}${question}: "
  read -rs answer
  echo >&2
  echo "$answer"
}
