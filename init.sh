#!/usr/bin/env bash

# --- SCRIPT SIGNATURE --- #
#
#     ██                  ██                                   ▄▄
#     ▀▀                  ▀▀       ██                          ██
#   ████     ██▄████▄   ████     ███████             ▄▄█████▄  ██▄████▄
#     ██     ██▀   ██     ██       ██                ██▄▄▄▄ ▀  ██▀   ██
#     ██     ██    ██     ██       ██                 ▀▀▀▀██▄  ██    ██
#  ▄▄▄██▄▄▄  ██    ██  ▄▄▄██▄▄▄    ██▄▄▄      ██     █▄▄▄▄▄██  ██    ██
#  ▀▀▀▀▀▀▀▀  ▀▀    ▀▀  ▀▀▀▀▀▀▀▀     ▀▀▀▀      ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#
#
# --- DESCRIPTION --- #
# Links all executable scripts (excluding specified paths) into ~/.local/bin/scripts
# --- DEPENDENCIES --- #
# - fd
# --- END SIGNATURE --- #

set -euo pipefail

trap 'exit 1' SIGUSR1

source "$(dirname $0)/utils.sh"

# ---  Main script logic --- #

error=$(
  cat <<END
The 'fd' command is not installed.
Please install it by following the instructions here:
  https://github.com/sharkdp/fd#installation
END
)

# For debian-based distros fd package is named fdfind
if command -v fdfind &>/dev/null; then
  sudo ln -si "$(which fdfind)" /usr/bin/fd 2>/dev/null
fi

if ! command -v fd &>/dev/null; then
  logError "${error}"
fi

SCRIPTS_DIR="$(dirname $0)"

sudo ln -sf "${SCRIPTS_DIR}/lib/cmdarg.sh" "${HOME}/.local/bin/scripts"
sudo ln -sf "${SCRIPTS_DIR}/clipcopy" "${HOME}/.local/bin/scripts/copyclip"
ln -sf "${SCRIPTS_DIR}/lib/cmdarg.sh" "${SCRIPTS_DIR}/cmdarg.sh"
ln -sf "${SCRIPTS_DIR}/clipcopy" "${SCRIPTS_DIR}/copyclip"

if ! echo ${PATH} | grep "${HOME}/.local/bin/scripts" -q; then
  echo "Add this line to your .$(basename ${SHELL})rc file to make the scripts globally available"
  printf 'export PATH="$PATH:$HOME/.local/bin/scripts"\n\n'
fi

# Define directories to exclude
EXCLUDE_DIRS=(
  "${SCRIPTS_DIR}/.git"
  "${SCRIPTS_DIR}/python/.venv"
  "${SCRIPTS_DIR}/init.sh"
  "${SCRIPTS_DIR}/cpp/release.sh"
)

# Dynamically add subdirectories of $HOME/scripts containing executables to PATH
# excluding specified directories and their subdirectories
if [[ -d "${SCRIPTS_DIR}" ]]; then
  sudo rm -rf "${HOME}/.local/bin/scripts" || printf ''
  sudo mkdir -p "${HOME}/.local/bin/scripts" || printf ''

  count=0

  for script in $(fd . -t x "${SCRIPTS_DIR}"); do
    exclude=false
    for excluded in "${EXCLUDE_DIRS[@]}"; do
      if [[ "$(dirname "${script}")" == "${excluded}"* || "${script}" == "${excluded}"* ]]; then
        exclude=true
        break
      fi
    done
    if ! ${exclude}; then
      sudo ln -s "${script}" "${HOME}/.local/bin/scripts" && ((count = count + 1))
    fi
  done
fi

log-success "Linked ${count} scripts to ${HOME}/.local/bin/scripts"
