#!/usr/bin/env bash
#
# --- SCRIPT SIGNATURE --- #
#
#                                ▄▄▄▄                                                        ▄▄
#                                ▀▀██                                                        ██
#   ██▄████   ▄████▄   ██▄███▄     ██       ▄█████▄   ▄█████▄   ▄████▄             ▄▄█████▄  ██▄████▄
#   ██▀      ██▄▄▄▄██  ██▀  ▀██    ██       ▀ ▄▄▄██  ██▀    ▀  ██▄▄▄▄██            ██▄▄▄▄ ▀  ██▀   ██
#   ██       ██▀▀▀▀▀▀  ██    ██    ██      ▄██▀▀▀██  ██        ██▀▀▀▀▀▀             ▀▀▀▀██▄  ██    ██
#   ██       ▀██▄▄▄▄█  ███▄▄██▀    ██▄▄▄   ██▄▄▄███  ▀██▄▄▄▄█  ▀██▄▄▄▄█     ██     █▄▄▄▄▄██  ██    ██
#   ▀▀         ▀▀▀▀▀   ██ ▀▀▀       ▀▀▀▀    ▀▀▀▀ ▀▀    ▀▀▀▀▀     ▀▀▀▀▀      ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#                      ██
#
# --- DESCRIPTION --- #
# String replacement with optional file inputs and backups
# --- DEPENDENCIES --- #
# - sed
# --- END SIGNATURE --- #

set -eo pipefail
trap 'exit 1' SIGUSR1

eval "$(include "lib/cmdarg.sh")"
eval "$(include "lib/helpers.sh")"
eval "$(include "check-deps")"
checkDeps "$0"

# --- cmdarg setup --- #
usage() {
  printf '\n\n'
  echo "Usage: $(basename "$0") <search> <replace> [OPTIONS]"
  echo "    search:  string to find"
  echo "    replace: string to replace with"
}
cmdarg_info "header" "$(get-desc "$0")$(usage)"

declare -a files
cmdarg "f?[]" "files" "Files to perform replace on"
cmdarg "b" "backup" "Have a backup of the original files"

cmdarg_parse "$@"
# ---  Main script logic --- #
backup="${cmdarg_cfg['backup']}"

# Check for minimum arguments
if ((argc < 2)); then
  log-warning "Missing required arguments"
  usage
  exit 1
fi

search="${argv[0]}"
replace="${argv[1]}"

# Escape special characters in search pattern
searchEscaped=$(printf '%s' "${search}" | sed 's|[[\\|.*^$/]|\\&|g')
replaceEscaped=$(printf '%s' "${replace}" | sed 's|[[\\|.*^$/]|\\&|g')

# If no files specified, process stdin
if ((${#files[@]} == 0)); then
  sed "s|${searchEscaped}|${replaceEscaped}|g"
fi

# Process each file
for file in "${files[@]}"; do
  [[ ! -r "${file}" ]] && log-error "File '${file}' is not readable"

  if isInteractiveShell; then
    # Create backup and perform replacement
    if [[ "${backup}" == true ]]; then
      cp -f "${file}" "${file}.bak" 2>/dev/null || log-error "Backup failed for ${file}"
    fi
  fi

  sed -i "s|${searchEscaped}|${replaceEscaped}|g" "${file}" 2>/dev/null || {
    log-warning "Replacement failed for ${file}"
    continue
  }

  log-success "Processed: $(humanQuote "${file}")"
done
