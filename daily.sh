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
# --- END SIGNATURE --- #

set -euo pipefail

trap 'exit 1' SIGUSR1

source check-deps
checkDeps "$0"
# ---  Main script logic --- #
DOTFILES="${HOME}/dotfiles"

chassis=$(hostnamectl chassis)

if [[ "${chassis}" == "laptop" ]]; then
  device="laptop"
else
  device="pc"
fi

# ---- Timeshift ---- #
sudo timeshift --create --comments "Daily backup $(now)"

# --- Installed packages --- #
pacman -Qqe >"${DOTFILES}/${device}_packages.txt"

# --- VS Code Extenstions--- #
get-ext --overwrite "${DOTFILES}/${device}_extensions.json"

# --- PNPM --- #
pnpm-ls >>"${DOTFILES}/pnpm_global_packages.txt"
no-dups --force "${DOTFILES}/pnpm_global_packages.txt"
