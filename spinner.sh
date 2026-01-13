#!/usr/bin/env bash
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

set -eo pipefail
shopt checkwinsize &>/dev/null
(:) # A little hack to trigger checkwinsize to work

trap 'exit 1' SIGUSR1

eval "$(include "lib/cmdarg.sh")"
eval "$(include "lib/helpers.sh")"
eval "$(include "check-deps")"

checkDeps "$0"
cmdarg "c?" "color" "Color of the spinner (black, red, green, yellow, blue, magenta, cyan, white, gray)" "green"
cmdarg "t?" "theme" "The theme of the spinner (available: dots, bar, circle)" "dots"
cmdarg_info "header" "$(get-desc "$0")"
cmdarg_parse "$@"
# ---  Main script logic --- #
color=${cmdarg_cfg['color']}
theme=${cmdarg_cfg['theme']}
msg=${argv[*]:-Loading...}
[[ -z ${msg} ]] && log-error "Message is required"

# make sure we restore cursor before exit
cleanup() {
  local sig=$1

  printf '\r'      # return to start
  printf '\e[2K'   # erase whole line
  printf '\e[?25h' # show cursor

  if [[ "${sig}" != TERM ]]; then
    printf '\e[%dm' "${colorCode}"                                   # set the foreground color
    printf '%s %s%s' "${currentSpinner}" "${msg%$'\n'}" "${padding}" # print the progress bar
    printf '\e[0m'                                                   # reset the foreground color
  fi

  exit 0
}

trap 'cleanup INT' INT
trap 'cleanup TERM' TERM
trap 'cleanup SIGUSR1' SIGUSR1

case "${theme}" in
dots) sp=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷") ;;
circle) sp=("⢎ " "⠎⠁" "⠊⠑" "⠈⠱" " ⡱" "⢀⡰" "⢄⡠" "⢆⡀") ;;
bar) sp=("▰▱▱▱▱▱▱" "▰▰▱▱▱▱▱" "▰▰▰▱▱▱▱" "▰▰▰▰▱▱▱" "▰▰▰▰▰▱▱" "▰▰▰▰▰▰▱" "▰▰▰▰▰▰▰" "▰▱▱▱▱▱▱") ;;
? | *) sp=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷") ;;
esac

msgLength=$((${#msg} + ${#sp[0]} + 1))

colorCode="$(mapColor "${color}")" || log-error "Invalid color '${color}'"

# hide cursor
printf '\e[?25l'

idx=0
currentIdx=0
currentSpinner="${sp[${currentIdx}]}"
while :; do
  pad=$((COLUMNS - msgLength))
  ((pad > 0)) && printf -v padding "%*s" "${pad}" ' '
  currentIdx=$((idx % ${#sp[@]}))
  currentSpinner="${sp[${currentIdx}]}"

  printf '\e[s'                                                    # save the cursor location
  printf '\e[2K'                                                   # clear the line
  printf '\e[%dm' "${colorCode}"                                   # set the foreground color
  printf '%s %s%s' "${currentSpinner}" "${msg%$'\n'}" "${padding}" # print the progress bar
  printf '\e[0m'                                                   # reset the foreground color
  printf '\e[u'                                                    # restore the cursor location

  sleep 0.1
  ((++idx))
done

exit 0
