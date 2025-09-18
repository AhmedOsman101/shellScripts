#!/usr/bin/env bash
# shellcheck disable=2317
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
# Displays a customizable colored spinner with a message, restoring the terminal state on exit or interruption.
# --- DEPENDENCIES --- #
#
# --- END SIGNATURE --- #

set -o pipefail
shopt checkwinsize &>/dev/null
(:) # A little hack to trigger checkwinsize to work

trap 'exit 1' SIGUSR1

eval "$(include "lib/cmdarg.sh")"
eval "$(include "lib/helpers.sh")"
eval "$(include "check-deps")"

checkDeps "$0"
# ---  Main script logic --- #
cmdarg_info "header" "$(get-desc "$0")"

cmdarg "c?" "color" "Color of the banner (black, red, green, yellow, blue, magenta, cyan, white, gray)" "green"

cmdarg_parse "$@"

color=${cmdarg_cfg['color']}
msg=${cmdarg_argv[*]:-Loading...}
[[ -z ${msg} ]] && log-error "Message is required"

trapsig=0

onkill() {
  trapsig="${BASH_TRAPSIG}"
  if ((trapsig != 2)); then
    printf '\r'      # return to start
    printf '\e[2K'   # erase whole line
    printf '\e[?25h' # show cursor
    printf '\e[2K'   # erase whole line
  fi
  exit 0
}

# make sure we restore cursor on exit or Ctrl-C
cleanup() {
  trapsig="${trapsig:-${BASH_TRAPSIG}}"
  if ((trapsig == 0)) || ((trapsig == 2)); then
    printf '\r'                                       # return to start
    printf '\e[2K'                                    # erase whole line
    printf '\e[?25h'                                  # show cursor
    tput setaf "${colorCode}"                         # set the foreground color
    printf '%s %s' "${currentSpinner}" "${msg%$'\n'}" # print the progress bar
    tput sgr0                                         # reset the foreground color
  fi
  return 0
}

trap 'cleanup' EXIT
trap 'onkill' INT TERM SIGUSR1

sp='⣾⣽⣻⢿⡿⣟⣯⣷'
msgLength=$((${#msg} + 2))
width=$((COLUMNS - msgLength))

for _ in $(seq 1 "${width}"); do
  msg+=' '
done

declare colorCode

case ${color} in
black) colorCode=0 ;;
red) colorCode=1 ;;
green) colorCode=2 ;;
yellow) colorCode=3 ;;
blue) colorCode=4 ;;
magenta) colorCode=5 ;;
cyan) colorCode=6 ;;
white) colorCode=7 ;;
gray | grey) colorCode=8 ;;
*) log-error "Invalid color '${color}'" ;;
esac

# hide cursor
printf '\e[?25l'

i=0
idx=0
currentSpinner="${sp:idx:1}"
while true; do
  # compute once, use everywhere
  idx=$((i % ${#sp}))
  currentSpinner="${sp:idx:1}"

  printf '\e7'                                # save the cursor location
  printf '\e[2K'                              # clear the line
  tput setaf "${colorCode}"                   # set the foreground color
  printf '%s %s' "${currentSpinner}" "${msg}" # print the progress bar
  tput sgr0                                   # reset the foreground color
  printf '\e8'                                # restore the cursor location

  sleep 0.1
  ((i++))
done

exit 0
