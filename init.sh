#!/usr/bin/env bash

set -euo pipefail

trap 'exit 1' SIGUSR1

SCRIPTS_DIR="${HOME}/scripts"

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

log-success "Linked ${count} scripts to ${HOME}/.local/bin"
