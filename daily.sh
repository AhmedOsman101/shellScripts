#!/usr/bin/env bash

DOTFILES="${HOME}/dotfiles"

chassis=$(hostnamectl chassis)

if [[ "${chassis}" == "laptop" ]]; then
  device="laptop"
else
  device="pc"
fi

# ---- paru packages ---- #
paru -Qqe >"${DOTFILES}/${device}_packages.txt"

# ---- vscode extenstions---- #
get-ext "${DOTFILES}/${device}_extensions.json" -o

# ---- pnpm ---- #
pnpm-ls >>"${DOTFILES}/pnpm_global_packages.txt"
no-dups "${DOTFILES}/pnpm_global_packages.txt"
