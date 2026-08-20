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

source "$(include "lib/helpers.sh")"
source "$(include "check-deps")"
checkDeps "$0"
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

isNewLine=true

if [[ "$1" =~ ^-n$ ]]; then
  isNewLine=false
  shift || true
fi

COLOR_FUNC="${LEVEL_COLORS[${LEVEL}]:-printCyan}"
OUTPUT_FD="${LEVEL_OUTPUT[${LEVEL}]:-1}"

# --- Read message --- #
message="$(input "$@")"

if "${isNewLine}"; then
  colorOnlyPrefix "${COLOR_FUNC}" "${LEVEL}" "${message}" "${OUTPUT_FD}"
else
  colorOnlyPrefix -n "${COLOR_FUNC}" "${LEVEL}" "${message}" "${OUTPUT_FD}"
fi
