#!/usr/bin/env bash
#
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

set -eo pipefail
trap 'exit 1' SIGUSR1

# ---  Main script logic --- #
SCRIPTS_DIR="$(dirname "${BASH_SOURCE[0]}")"
DOTFILES="${HOME}/dotfiles"

export PATH="${PATH}:${SCRIPTS_DIR}:${HOME}/.local/share/pnpm"
export TERM=xterm

eval "$(include "check-deps")"
checkDeps "$0"

chassis=$(hostnamectl chassis)

if [[ "${chassis}" == "laptop" ]]; then
  device="laptop"
else
  device="pc"
fi

# ---- Timeshift ---- #
# SUDO_ASKPASS="${SCRIPTS_DIR}/echopass" sudo -A timeshift --create --comments "Daily backup $(now)"

# --- Installed packages --- #
pacman -Qqe >"${DOTFILES}/${device}_packages.txt"

# --- VS Code Extenstions--- #
get-ext --overwrite "${DOTFILES}/${device}_extensions.json"

# --- PNPM --- #
pnpm-ls >>"${DOTFILES}/pnpm_global_packages.txt"

no-dups --force "${DOTFILES}/pnpm_global_packages.txt"

notify-send "Daily system backup finished!" &
