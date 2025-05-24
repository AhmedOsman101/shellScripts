#!/usr/bin/env bash

# --- SCRIPT SIGNATURE --- #
#
#        ▄▄               ██     ▄▄▄▄                                    ▄▄
#        ██               ▀▀     ▀▀██                                    ██
#   ▄███▄██   ▄█████▄   ████       ██      ▀██  ███            ▄▄█████▄  ██▄████▄
#  ██▀  ▀██   ▀ ▄▄▄██     ██       ██       ██▄ ██             ██▄▄▄▄ ▀  ██▀   ██
#  ██    ██  ▄██▀▀▀██     ██       ██        ████▀              ▀▀▀▀██▄  ██    ██
#  ▀██▄▄███  ██▄▄▄███  ▄▄▄██▄▄▄    ██▄▄▄      ███       ██     █▄▄▄▄▄██  ██    ██
#    ▀▀▀ ▀▀   ▀▀▀▀ ▀▀  ▀▀▀▀▀▀▀▀     ▀▀▀▀      ██        ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#                                           ███
#
# --- DESCRIPTION --- #
# Creates daily Timeshift backup, exports installed packages, VS Code extensions, and unique pnpm global packages
# --- DEPENDENCIES --- #
# - timeshift
# - sudo
# --- END SIGNATURE --- #

set -euo pipefail

trap 'exit 1' SIGUSR1

# ---  Main script logic --- #
SCRIPTS_DIR="$(dirname $0)"
DOTFILES="${HOME}/dotfiles"

source "${SCRIPTS_DIR}/check-deps"
checkDeps "$0"

chassis=$(hostnamectl chassis)

if [[ "${chassis}" == "laptop" ]]; then
  device="laptop"
else
  device="pc"
fi

# ---- Timeshift ---- #
SUDO_ASKPASS="${SCRIPTS_DIR}/echopass" sudo -A timeshift --create --comments "Daily backup $(now)"

# --- Installed packages --- #
paru -Qqe >"${DOTFILES}/${device}_packages.txt"

# --- VS Code Extenstions--- #
"${SCRIPTS_DIR}/get-ext" --overwrite "${DOTFILES}/${device}_extensions.json"

# --- PNPM --- #
"${SCRIPTS_DIR}/pnpm-ls" >>"${DOTFILES}/pnpm_global_packages.txt"
"${SCRIPTS_DIR}/no-dups" --force "${DOTFILES}/pnpm_global_packages.txt"
