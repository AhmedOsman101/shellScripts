#!/usr/bin/env bash
#
# --- SCRIPT SIGNATURE --- #
#
#                         ██                                 ▄▄
#                         ▀▀                                 ██
#  ▄▄█████▄  ██▄███▄    ████     ██▄████▄          ▄▄█████▄  ██▄████▄
#  ██▄▄▄▄ ▀  ██▀  ▀██     ██     ██▀   ██          ██▄▄▄▄ ▀  ██▀   ██
#   ▀▀▀▀██▄  ██    ██     ██     ██    ██           ▀▀▀▀██▄  ██    ██
#  █▄▄▄▄▄██  ███▄▄██▀  ▄▄▄██▄▄▄  ██    ██   ██     █▄▄▄▄▄██  ██    ██
#   ▀▀▀▀▀▀   ██ ▀▀▀    ▀▀▀▀▀▀▀▀  ▀▀    ▀▀   ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#            ██
#
# --- DESCRIPTION --- #
# Displays a customizable colored spinner with a message.
# --- DEPENDENCIES --- #
#
# --- END SIGNATURE --- #

set -eo pipefail

trap 'exit 1' SIGUSR1

eval "$(include "lib/cmdarg.sh")"
eval "$(include "lib/helpers.sh")"
eval "$(include "check-deps")"

checkDeps "$0"
cmdarg "c?" "color" "Color of the banner (black, red, green, yellow, blue, magenta, cyan, white, gray)" "green"
cmdarg_info "header" "$(get-desc "$0")"
cmdarg_parse "$@"
# ---  Main script logic --- #
# ---- internal state ----
__spinner_pid=
__spinner_active=0
__spinner_color=
__spinner_msg=

# ---- spinner worker ----
__spinner_loop() {
  local sp='⣾⣽⣻⢿⡿⣟⣯⣷'
  local idx=0
  local currentSpinner
  local padding
  local msgLength
  local colorCode

  msgLength=$((${#__spinner_msg} + 2))
  colorCode="$(mapColor "${__spinner_color}")" || exit 1

  # hide cursor
  printf '\e[?25l'

  while :; do
    pad=$((COLUMNS - msgLength))
    ((pad > 0)) && printf -v padding "%*s" "${pad}" ' '

    currentSpinner="${sp:idx%${#sp}:1}"

    printf '\e[s'
    printf '\e[%dm' "${colorCode}"
    printf '%s %s%s' "${currentSpinner}" "${__spinner_msg%$'\n'}" "${padding}"
    printf '\e[0m'
    printf '\e[u'

    sleep 0.1
    ((++idx))
  done
}

# ---- cleanup ----
__spinner_cleanup() {
  local sig=$1

  ((__spinner_active)) || return 0

  kill -9 "${__spinner_pid}" 2>/dev/null || true
  wait "${__spinner_pid}" 2>/dev/null || true

  printf '\e[?25h' # show cursor

  if [[ "${sig}" != TERM ]]; then
    local colorCode
    colorCode="$(mapColor "${__spinner_color}")" || true
    printf '\r'
    printf '\e[%dm' "${colorCode}"
    printf '✓ %s\n' "${__spinner_msg%$'\n'}"
    printf '\e[0m'
  fi

  __spinner_pid=
  __spinner_active=0
}

# ---- public API ----
spinnerStart() {
  local color="${1:-green}"
  shift || true
  local msg="${*:-Loading...}"

  isInteractiveShell || return 0
  ((__spinner_active)) && return 0

  __spinner_color="${color}"
  __spinner_msg="${msg}"

  __spinner_loop &
  __spinner_pid=$!
  __spinner_active=1

  trap '__spinner_cleanup INT' INT
  trap '__spinner_cleanup TERM' TERM
  trap '__spinner_cleanup SIGUSR1' SIGUSR1
  trap '__spinner_cleanup EXIT' EXIT
}

spinnerEnd() {
  __spinner_cleanup TERM
  trap - INT TERM SIGUSR1 EXIT
}
