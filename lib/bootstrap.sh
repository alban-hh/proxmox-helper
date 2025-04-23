PXH_REPO="${PXH_REPO:-https://raw.githubusercontent.com/alban-hh/proxmox-helper/main}"
PXH_LIBS=(colors output runtime network packages prompts github docker services users backup toolchains postgres pve addon)

pxh_local_lib_dir() {
  local src="${BASH_SOURCE[0]:-}"
  if [[ -n "$src" && -f "$src" && "$src" != /dev/fd/* ]]; then
    dirname "$src"
  fi
}

pxh_load_libs() {
  local dir lib
  dir="$(pxh_local_lib_dir)"
  for lib in "${PXH_LIBS[@]}"; do
    if [[ -n "$dir" && -f "${dir}/${lib}.sh" ]]; then
      . "${dir}/${lib}.sh"
    else
      . <(curl -fsSL "${PXH_REPO}/lib/${lib}.sh")
    fi
  done
}

pxh_load_libs
set_std_mode
enable_error_handling
