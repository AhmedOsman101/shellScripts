#!/usr/bin/env bash
#
# --- SCRIPT SIGNATURE --- #
#
#     ▄▄▄▄         ▄▄                      ▄▄
#    ██▀▀▀         ██                      ██
#  ███████    ▄███▄██            ▄▄█████▄  ██▄████▄
#    ██      ██▀  ▀██            ██▄▄▄▄ ▀  ██▀   ██
#    ██      ██    ██             ▀▀▀▀██▄  ██    ██
#    ██      ▀██▄▄███     ██     █▄▄▄▄▄██  ██    ██
#    ▀▀        ▀▀▀ ▀▀     ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#
#
# --- END SIGNATURE --- #

set -eo pipefail
trap 'exit 1' SIGUSR1

source "$(include "lib/helpers.sh")"
# ---  Main script logic --- #
resolveFd() {
  command -v fd 2>/dev/null ||
    command -v fdfind 2>/dev/null ||
    return 1
}

cmdArray=(
  "$(resolveFd)"
  '--hidden'
)

excludes=(
  '.git'
  'node_modules'
  'vendor'
  '.cache'
  'dist'
  'build'
  'venv'
  '.venv'
)

for exclude in "${excludes[@]}"; do
  cmdArray+=(--exclude "${exclude}")
done

cmdArray+=("$@")

"${cmdArray[@]}"
