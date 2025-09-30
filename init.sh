#!/usr/bin/env bash
#
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
# - fd | fdfind (fd-find)
# - realpath
# --- END SIGNATURE --- #

set -uo pipefail

trap 'exit 1' SIGUSR1

# ---  Main script logic --- #
export PATH="${PATH}:$(dirname "$0")"

file="$(dirname "$0")/check-deps"
declare -a scripts

if [[ -f "${file}" ]]; then
  source "${file}"
  checkDeps "$0"
else
  echo "Dependency check script not found at ${file}" 1>&2
  exit 1
fi

# For debian-based distros fd package is named fdfind
if command -v fdfind &>/dev/null; then
  logInfo "Creating a symlink from fdfind to /usr/bin/fd"
  sudo ln -sf "$(command -v fdfind)" /usr/bin/fd 2>/dev/null
fi

error=$(
  cat <<END
The 'fd' command is not installed.
Please install it by following the instructions here:
  https://github.com/sharkdp/fd#installation
END
)

if ! command -v fd &>/dev/null; then
  logError "${error}"
fi

SCRIPTS_DIR="${HOME}/scripts"
DESTINATION_DIR="${HOME}/.local/bin/scripts"

if [[ ! -d "${SCRIPTS_DIR}" ]]; then
  logError "The scripts directory must exist at ${SCRIPTS_DIR}"
fi

# Create destination directory with correct permissions
if [[ ! -d "${DESTINATION_DIR}" ]]; then
  sudo mkdir -p "${DESTINATION_DIR}" || logError "Failed to create ${DESTINATION_DIR}"
fi

sudo chown -R "${USER}:${USER}" "${DESTINATION_DIR}" || logError "Failed to make ${USER} the owner of ${DESTINATION_DIR}"

# Ensure DESTINATION_DIR is user-writable
if [[ ! -w "${DESTINATION_DIR}" ]]; then
  logError "${DESTINATION_DIR} is not writable by user ${USER}"
fi

# Remove existing symlinks
fd . -t l -t x "${DESTINATION_DIR}" -x sudo rm 2>/dev/null || true

# Create symlinks
sudo ln -sf "${SCRIPTS_DIR}/lib/cmdarg.sh" "${DESTINATION_DIR}/cmdarg.sh" || logError "Failed to link cmdarg.sh"
ln -sf "${SCRIPTS_DIR}/lib/cmdarg.sh" "${SCRIPTS_DIR}/cmdarg.sh" || logError "Failed to link cmdarg.sh"

sudo ln -sf "${SCRIPTS_DIR}/clipcopy" "${DESTINATION_DIR}/copyclip" || logError "Failed to link copyclip"
ln -sf "${SCRIPTS_DIR}/clipcopy" "${SCRIPTS_DIR}/copyclip" || logError "Failed to link copyclip"

if ! echo "${PATH}" | grep "${DESTINATION_DIR}" -q; then
  echo "Add this to your .$(basename "${SHELL}")rc file to make scripts globally available:"

  # shellcheck disable=2016 # literally print it don't expand
  printf 'export PATH="$PATH:$HOME/.local/bin/scripts"\n\n'
fi

mapfile -t scripts < <(
  fd . -t x "${SCRIPTS_DIR}" \
    -E ".git" \
    -E "python/.venv" \
    -E "init.sh" \
    -E "release.sh"
)

count=0
# Create symlinks for all executable scripts, excluding specified paths
for script in "${scripts[@]}"; do
  if sudo ln -sf "${script}" "${DESTINATION_DIR}/$(basename "${script}")" 2>/dev/null; then
    ((++count))
  else
    logInfo "Failed to link ${script}"
  fi
done

log-success "Linked ${count} scripts to ${DESTINATION_DIR}"
