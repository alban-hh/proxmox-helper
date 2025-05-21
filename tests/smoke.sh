#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0

fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "ok: $1"
}

check_library_loads() {
  if (cd "$ROOT" && bash -c '. lib/bootstrap.sh; declare -F msg_ok run_addon fetch_gh_release >/dev/null'); then
    pass "library loads and exposes core functions"
  else
    fail "library failed to load"
  fi
}

check_addon_syntax() {
  local file
  for file in "$ROOT"/addons/*.sh; do
    bash -n "$file" || fail "syntax error in ${file##*/}"
  done
  pass "all addons parse"
}

check_addon_contract() {
  local file name
  for file in "$ROOT"/addons/*.sh; do
    name="${file##*/}"
    grep -q '^APP=' "$file" || fail "${name} does not set APP"
    grep -q '^APP_SLUG=' "$file" || fail "${name} does not set APP_SLUG"
    grep -q 'lib/bootstrap.sh' "$file" || fail "${name} does not load the bootstrap"
    if grep -q '^run_addon' "$file"; then
      grep -q '^is_installed()' "$file" || fail "${name} lacks is_installed"
      grep -q '^install()' "$file" || fail "${name} lacks install"
    elif grep -q '^run_tool' "$file"; then
      grep -q '^main()' "$file" || fail "${name} lacks main"
    else
      fail "${name} calls neither run_addon nor run_tool"
    fi
    [[ "$(grep -o '^APP_SLUG="[^"]*"' "$file" | cut -d'"' -f2)" == "${name%.sh}" ]] || fail "${name} slug does not match file name"
  done
  pass "all addons follow the contract"
}

check_help_output() {
  local file
  for file in "$ROOT"/addons/*.sh; do
    bash "$file" --help >/dev/null 2>&1 || fail "${file##*/} --help failed"
  done
  pass "all addons answer --help"
}

check_no_comments() {
  local hits
  hits="$(grep -rnE '^\s*#[^!]' "$ROOT"/lib "$ROOT"/addons "$ROOT"/bin | grep -v 'shellcheck' || true)"
  if [[ -n "$hits" ]]; then
    echo "$hits" >&2
    fail "comments found in shell sources"
  else
    pass "no comments in shell sources"
  fi
}

check_library_loads
check_addon_syntax
check_addon_contract
check_help_output
check_no_comments

if ((FAILURES > 0)); then
  echo "${FAILURES} check(s) failed" >&2
  exit 1
fi
echo "all checks passed"
