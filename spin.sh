#!/usr/bin/env bash
#
# --- SCRIPT SIGNATURE --- #
#
#                         ██                                                                 ▄▄
#                         ▀▀                                                                 ██
#  ▄▄█████▄  ██▄███▄    ████     ██▄████▄  ██▄████▄   ▄████▄    ██▄████            ▄▄█████▄  ██▄████▄
#  ██▄▄▄▄ ▀  ██▀  ▀██     ██     ██▀   ██  ██▀   ██  ██▄▄▄▄██   ██▀                ██▄▄▄▄ ▀  ██▀   ██
#   ▀▀▀▀██▄  ██    ██     ██     ██    ██  ██    ██  ██▀▀▀▀▀▀   ██                  ▀▀▀▀██▄  ██    ██
#  █▄▄▄▄▄██  ███▄▄██▀  ▄▄▄██▄▄▄  ██    ██  ██    ██  ▀██▄▄▄▄█   ██          ██     █▄▄▄▄▄██  ██    ██
#   ▀▀▀▀▀▀   ██ ▀▀▀    ▀▀▀▀▀▀▀▀  ▀▀    ▀▀  ▀▀    ▀▀    ▀▀▀▀▀    ▀▀          ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#            ██
#
# --- DESCRIPTION --- #
# Displays a customizable colored spinner with a message.
# --- DEPENDENCIES --- #
# - gum
# --- END SIGNATURE --- #

set -eo pipefail

trap 'exit 1' SIGUSR1

eval "$(include "lib/cmdarg.sh")"
eval "$(include "lib/helpers.sh")"
eval "$(include "check-deps")"

checkDeps "$0"
cmdarg_info "header" "$(get-desc "$0")"
# ---  Main script logic --- #
cmdarg "c?" "color" "Color of the banner (black, red, green, yellow, blue, magenta, cyan, white, gray)" "green"

cmdarg_parse "$@"

color="${cmdarg_cfg['color']}"
msg="${argv[*]:-Loading...}"
[[ -z "${msg}" ]] && log-error "Message is required"

colorCode="$(mapColor "${color}")" || log-error "Invalid color '${color}'"

gum spin \
  --title="${msg}" \
  --spinner.foreground="${colorCode}" \
  --title.foreground="${colorCode}" \
  -- sleep infinity
