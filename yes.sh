#!/usr/bin/env bash
#
# --- SCRIPT SIGNATURE --- #
#
#                                                    ▄▄
#                                                    ██
#  ▀██  ███   ▄████▄   ▄▄█████▄            ▄▄█████▄  ██▄████▄
#   ██▄ ██   ██▄▄▄▄██  ██▄▄▄▄ ▀            ██▄▄▄▄ ▀  ██▀   ██
#    ████▀   ██▀▀▀▀▀▀   ▀▀▀▀██▄             ▀▀▀▀██▄  ██    ██
#     ███    ▀██▄▄▄▄█  █▄▄▄▄▄██     ██     █▄▄▄▄▄██  ██    ██
#     ██       ▀▀▀▀▀    ▀▀▀▀▀▀      ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#   ███
#
# --- DESCRIPTION --- #
# Output a string repeatedly until killed
# --- DEPENDENCIES --- #
#
# --- END SIGNATURE --- #

set -eo pipefail
trap 'exit 1' SIGUSR1

eval "$(include "lib/cmdarg.sh")"
eval "$(include "lib/helpers.sh")"
eval "$(include "check-deps")"
checkDeps "$0"

# --- cmdarg setup --- #
cmdarg_info "header" "$(get-desc "$0")"
cmdarg_parse "$@"
# ---  Main script logic --- #
while :; do
  printf '%s\n' "${argv[0]:-y}"
  sleep 0.05 # 50ms delay
done
