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
# Displays a customizable colored spinner with a message. (source the files)
# --- END SIGNATURE --- #

set -eo pipefail
trap 'exit 1' SIGUSR1

eval "$(include "lib/helpers.sh")"
# ---  Main script logic --- #
# ---- internal state ----
__spinner_pid=
__spinner_active=0
__spinner_color=
__spinner_msg=
__spinner_parent_pid=
__spinner_intentional_end=0

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
    # Check if parent process is still alive
    if ! kill -0 "${__spinner_parent_pid}" 2>/dev/null; then
      # Parent died, exit cleanly
      printf '\e[?25h'
      exit 0
    fi

    pad=$((COLUMNS - msgLength))
    ((pad > 0)) && printf -v padding "%*s" "${pad}" ' '

    currentSpinner="${sp:idx%${#sp}:1}"

    printf '\e[%dm' "${colorCode}"                                             # set the foreground color
    printf '%s %s%s' "${currentSpinner}" "${__spinner_msg%$'\n'}" "${padding}" # print the progress bar
    printf '\e[0m'                                                             # reset the foreground color
    printf '\r'                                                                # move to start of line

    sleep 0.1
    ((++idx))
  done
}

# ---- cleanup ----
__spinner_cleanup() {
  local sig=$1

  ((__spinner_active)) || return 0

  # Try graceful termination first
  kill -TERM "${__spinner_pid}" 2>/dev/null || true

  # Wait a bit for graceful shutdown
  local count=0
  while kill -0 "${__spinner_pid}" &>/dev/null && ((count < 5)); do
    sleep 0.05
    ((count++))
  done

  # Force kill if still running
  kill -KILL "${__spinner_pid}" 2>/dev/null || true
  wait "${__spinner_pid}" 2>/dev/null || true

  printf '\e[?25h' # show cursor

  # Only show success message for unexpected termination, not intentional end
  if ! ((__spinner_intentional_end)); then
    local colorCode
    colorCode="$(mapColor "${__spinner_color}")" || true
    printf '\r'
    printf '\e[%dm' "${colorCode}"
    printf '✓ %s\n' "${__spinner_msg%$'\n'}"
    printf '\e[0m'
  fi

  __spinner_pid=
  __spinner_parent_pid=
  __spinner_active=0
  __spinner_intentional_end=0
}

# ---- public API ----
spinnerStart() {
  local opt OPTARG OPTIND color msg

  while getopts 'c:' opt; do
    case "${opt}" in
    c) color="$(OPTARG)" ;;
    *) true ;;
    esac
  done
  shift "$((OPTIND - 1))"

  color="${color:-green}"
  msg="${*:-Loading...}"

  isInteractiveShell || return 0
  ((__spinner_active)) && return 0

  __spinner_color="${color}"
  __spinner_msg="${msg}"
  __spinner_parent_pid=$$

  # Start spinner in a new process group for better signal handling
  set -m
  __spinner_loop 1>&2 &
  __spinner_pid=$!
  __spinner_active=1
  set +m

  trap '__spinner_cleanup INT 1>&2' INT
  trap '__spinner_cleanup TERM 1>&2' TERM
  trap '__spinner_cleanup SIGUSR1 1>&2' SIGUSR1
  trap '__spinner_cleanup EXIT 1>&2' EXIT
}

spinnerEnd() {
  __spinner_intentional_end=1
  __spinner_cleanup TERM 1>&2
  trap - INT TERM SIGUSR1 EXIT
}
