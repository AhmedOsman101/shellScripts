#!/usr/bin/env bash

DOTFILES="${HOME}/dotfiles"

# ---- paru packages ---- #
paru -Qqe >"${DOTFILES}/pc_packages.txt"

# ---- vscode extenstions---- #
get-ext "${DOTFILES}/pc_extensions.json" -o

# ---- pnpm ---- #
pnpm-ls >>"${DOTFILES}/pnpm_global_packages.txt"
no-dups "${DOTFILES}/pnpm_global_packages.txt"
