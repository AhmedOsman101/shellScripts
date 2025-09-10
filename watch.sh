#!/usr/bin/env bash

# --- SCRIPT SIGNATURE --- #
#
#                                          ▄▄                            ▄▄
#                        ██                ██                            ██
# ██      ██  ▄█████▄  ███████    ▄█████▄  ██▄████▄            ▄▄█████▄  ██▄████▄
# ▀█  ██  █▀  ▀ ▄▄▄██    ██      ██▀    ▀  ██▀   ██            ██▄▄▄▄ ▀  ██▀   ██
#  ██▄██▄██  ▄██▀▀▀██    ██      ██        ██    ██             ▀▀▀▀██▄  ██    ██
#  ▀██  ██▀  ██▄▄▄███    ██▄▄▄   ▀██▄▄▄▄█  ██    ██     ██     █▄▄▄▄▄██  ██    ██
#   ▀▀  ▀▀    ▀▀▀▀ ▀▀     ▀▀▀▀     ▀▀▀▀▀   ▀▀    ▀▀     ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#
#
# --- DESCRIPTION --- #
# Watches files with specified extensions and runs a given command using watchexec
# --- DEPENDENCIES --- #
# - watchexec
# - gum
# --- END SIGNATURE --- #

set -eo pipefail

trap 'exit 1' SIGUSR1

eval "$(include "lib/cmdarg.sh")"

eval "$(include "check-deps")"
checkDeps "$0"
# ---  Main script logic --- #
cmdarg_info "header" "$(get-desc "$0")"

cmdarg "d?" "debounce" "Time to wait for new events before taking action" "5s"
cmdarg "c?" "command" "The command to run" ""

cmdarg_parse "$@"

cmd=${cmdarg_cfg['command']}
debounce=${cmdarg_cfg['debounce']}
exts=${cmdarg_argv[*]}

# Get the extensions string
# Prompt user for extensions if not provided as arguments
if [[ -z "${exts}" ]]; then
  extensions_str=$(gum input --header="Enter file extensions (space-separated, e.g., ts js md)" --placeholder="...")
  # Convert extensions string to array
  extensionsArray=("${extensions_str}")
  extensions=$(joinarr ',' "${extensionsArray[@]}")
else
  # Build a comma-separated string of extensions
  extensions=$(joinarr ',' "${exts[@]}")
fi

# Prompt user for the command to run if not provided
if [[ -z "${cmd}" ]]; then
  cmd=$(gum input --placeholder="Enter the command to execute on changes...")
fi

# Run watchexec with the provided command
watchexec -c --timings \
  --delay-run 1s \
  --debounce "${debounce}" \
  --exts "${extensions}" \
  -- "${cmd}" &&
  exit $?
