#!/usr/bin/env bash
# shellcheck disable=2183
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
cmdarg_info "header" "$(get-desc "$0")"
# ---  Main script logic --- #

cmdarg "c?" "color" "Color of the spinner (black, red, green, yellow, blue, magenta, cyan, white, gray)" "green"

cmdarg_parse "$@"

color=${cmdarg_cfg['color']}
msg=${argv[*]:-Loading...}
[[ -z ${msg} ]] && log-error "Message is required"

# make sure we restore cursor before exit
cleanup() {
  local sig=$1

  printf '\r'      # return to start
  printf '\e[2K'   # erase whole line
  printf '\e[?25h' # show cursor

  if [[ "${sig}" != TERM ]]; then
    printf '\e[3%sm' "${colorCode}"                                  # set the foreground color
    printf '%s %s%s' "${currentSpinner}" "${msg%$'\n'}" "${padding}" # print the progress bar
    printf '\e[0m'                                                   # reset the foreground color
  fi

  exit 0
}

trap 'cleanup INT' INT
trap 'cleanup TERM' TERM
trap 'cleanup SIGUSR1' SIGUSR1

sp='⣾⣽⣻⢿⡿⣟⣯⣷'
msgLength=$((${#msg} + 2))

colorCode="$(mapColor "${color}")" || log-error "Invalid color '${color}'"

# hide cursor
printf '\e[?25l'

idx=0
currentSpinner="${sp:idx:1}"
while :; do
  pad=$((COLUMNS - msgLength))
  ((pad > 0)) && printf -v padding "%*s" "${pad}"
  currentSpinner="${sp:idx%${#sp}:1}"

  printf '\e[s'                                                    # save the cursor location
  printf '\e[2K'                                                   # clear the line
  printf '\e[3%sm' "${colorCode}"                                  # set the foreground color
  printf '%s %s%s' "${currentSpinner}" "${msg%$'\n'}" "${padding}" # print the progress bar
  printf '\e[0m'                                                   # reset the foreground color
  printf '\e[u'                                                    # restore the cursor location

  sleep 0.1
  ((++idx))
done

exit 0
