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

eval "$(include "lib/helpers.sh")"
# ---  Main script logic --- #
cmdArray=(
  '/usr/bin/fd'
  '--hidden'
)

excludes=(
  '.git'
  'node_modules'
  'vendor'
  '.cache'
  'dist'
  'build'
)

for exclude in "${excludes[@]}"; do
  cmdArray+=(--exclude "${exclude}")
done

cmdArray+=("$@")

"${cmdArray[@]}"
