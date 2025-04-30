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

set -euo pipefail

trap 'exit 1' SIGUSR1

# ---  Main script logic --- #
# Check if 'watchexec' is installed
if ! command -v watchexec &>/dev/null; then
  echo "'watchexec' is not installed. Please install it to proceed." >&2
  exit 1
fi

# Get the extensions string
# Prompt user for extensions if not provided as arguments
if [[ -z "$1" ]]; then
  extensions_str=$(gum input --header="Enter file extensions (space-separated, e.g., ts js md):")
else
  extensions_str="$1"
fi

# Convert extensions string to array
extensionsArray=("${extensions_str}")

# Build a comma-separated string of extensions
extensions=$(
  IFS=,
  echo "${extensionsArray[*]}"
)

# Prompt user for the command to run if not provided
if [[ -z "$2" ]]; then
  command_to_run=$(gum input --header="Enter the command to execute on changes:")
else
  shift
  command_to_run="$*"
fi

# Run watchexec with the provided command
watchexec -c --timings \
  --delay-run 1s \
  --debounce 5s \
  --exts "${extensions}" \
  -- "${command_to_run}"
