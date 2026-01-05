#!/usr/bin/env bash
#
# --- SCRIPT SIGNATURE --- #
#
#  ▄▄▄▄                                              ▄▄
#  ▀▀██                                              ██
#    ██       ▄████▄    ▄███▄██            ▄▄█████▄  ██▄████▄
#    ██      ██▀  ▀██  ██▀  ▀██            ██▄▄▄▄ ▀  ██▀   ██
#    ██      ██    ██  ██    ██             ▀▀▀▀██▄  ██    ██
#    ██▄▄▄   ▀██▄▄██▀  ▀██▄▄███     ██     █▄▄▄▄▄██  ██    ██
#     ▀▀▀▀     ▀▀▀▀     ▄▀▀▀ ██     ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#                       ▀████▀▀
#
# --- DESCRIPTION --- #
# Unified logger for CLI apps, Supports stdin or arguments
# --- DEPENDENCIES --- #
#
# --- END SIGNATURE --- #

set -eo pipefail
trap 'exit 1' SIGUSR1

# eval "$(include "lib/cmdarg.sh")"
eval "$(include "lib/helpers.sh")"
eval "$(include "check-deps")"
checkDeps "$0"

# --- cmdarg setup --- #
# cmdarg_info "header" "$(get-desc "$0")"
# cmdarg_parse "$@"
# ---  Main script logic --- #

# --- Define color mapping --- #
declare -A LEVEL_COLORS=(
  [DEBUG]=printMagenta
  [INFO]=printPurple
  [SUCCESS]=printGreen
  [WARNING]=printYellow
  [ERROR]=printRed
)

declare -A LEVEL_OUTPUT=(
  [DEBUG]=1
  [INFO]=1
  [SUCCESS]=1
  [WARNING]=2
  [ERROR]=2
)

# --- Parse arguments --- #
LEVEL="${1:-INFO}"
shift || true

COLOR_FUNC="${LEVEL_COLORS[${LEVEL}]:-printPurple}"
OUTPUT_FD="${LEVEL_OUTPUT[${LEVEL}]:-1}"

# --- Read message --- #
message="$(input "$@")"

colorOnlyPrefix "${COLOR_FUNC}" "${LEVEL}" "${message}" "${OUTPUT_FD}"
