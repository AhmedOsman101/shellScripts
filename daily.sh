#!/usr/bin/env bash

DOTFILES="${HOME}/dotfiles"

chassis=$(hostnamectl chassis)

if [[ "${chassis}" == "laptop" ]]; then
  device="laptop"
else
  device="pc"
fi

# ---- Timeshift ---- #
sudo timeshift --create --comments "Daily backup $(now)"

# --- installed packages --- #
paru -Qqe >"${DOTFILES}/${device}_packages.txt"

# --- vscode extenstions--- #
get-ext "${DOTFILES}/${device}_extensions.json" -o

# --- pnpm --- #
pnpm-ls >>"${DOTFILES}/pnpm_global_packages.txt"
no-dups -f "${DOTFILES}/pnpm_global_packages.txt"
