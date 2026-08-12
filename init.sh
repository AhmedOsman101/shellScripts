#!/usr/bin/env bash
# shellcheck disable=2016
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
# Verifies the scripts repo setup and wires the path hook into shell configs
# --- DEPENDENCIES --- #
# - fd | fdfind (fd-find)
# --- END SIGNATURE --- #

set -eo pipefail
trap 'exit 1' SIGUSR1

INIT_DIR="$(dirname "${BASH_SOURCE[0]}")"
export PATH="${PATH}:${INIT_DIR}"

checkDepsFile="${INIT_DIR}/check-deps"
if [[ -s "${checkDepsFile}" ]]; then
  source "${checkDepsFile}"
  checkDeps "${BASH_SOURCE[0]}"
else
  echo "Dependency check script not found at ${checkDepsFile}" >&2
  exit 1
fi

source "$(include "lib/cmdarg.sh")"
source "$(include "lib/helpers.sh")"

# --- cmdarg setup --- #
declare -a shells
cmdarg_info "header" "$(get-desc "$0")"
# shellcheck disable=SC2034 # It's used by cmdarg
cmdarg "s?[]" "shells" 'Shell config(s) to install into'

# shellcheck disable=2218
usageMsg="$(cmdarg_usage)"
unset -f 'cmdarg_usage'

cmdarg_usage() {
  echo "${usageMsg}"
  cat <<EOF

Environment Variables:
EOF
  printf "  %-32s - %s\n" "SCRIPTS_DIR" "Source repo path (default: ~/scripts)"
  printf "  %-32s - %s\n" "SCRIPTS_HOOK_EXCLUDE" "Space-separated exclusion patterns (default: .git .venv venv node_modules)"

  exit "${1:-0}"
}

cmdarg_parse "$@"
# ---  Main script logic --- #

sourceLine='[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source "${SCRIPTS_DIR}/hooks/path.sh"'

: "${SCRIPTS_DIR:=${HOME}/scripts}"

# --- Verify dependencies --- #

if [[ ! -d "${SCRIPTS_DIR}" ]]; then
  logError "SCRIPTS_DIR is set to a nonexistent directory: ${SCRIPTS_DIR}"
fi

if ! command -v fd &>/dev/null; then
  if command -v fdfind &>/dev/null; then
    if yesNo "fdfind is installed but fd is not. Create symlink /usr/bin/fd -> $(command -v fdfind)?"; then
      sudo ln -sv "$(command -v fdfind)" /usr/bin/fd
    else
      logError "fd is required. Install it manually or re-run and accept the symlink prompt."
    fi
  else
    logError "fd is not installed. Install it: https://github.com/sharkdp/fd#installation"
  fi
fi

hookFile="${SCRIPTS_DIR}/hooks/path.sh"
if [[ ! -s "${hookFile}" ]]; then
  logError "Hook file not found: ${hookFile}"
fi

logInfo "Verified: SCRIPTS_DIR, fd, and hook file all present"

# --- Determine target shells --- #

declare -a targetShells
if ((${#shells[@]})); then
  for s in "${shells[@]}"; do
    case "${s}" in
    bash | zsh) targetShells+=("${s}") ;;
    *) logError "Unsupported shell: ${s} (supported: bash, zsh)" ;;
    esac
  done
else
  case "$(basename "${SHELL}")" in
  bash) targetShells=(bash) ;;
  zsh) targetShells=(zsh) ;;
  *) logError "Could not detect shell from \$SHELL=${SHELL}. Use -s bash or -s zsh." ;;
  esac
fi

# --- Get shell config path --- #

getShellConfig() {
  case "$1" in
  bash) echo "${HOME}/.bashrc" ;;
  zsh) echo "${ZDOTDIR:-${HOME}}/.zshrc" ;;
  *) : ;;
  esac
}

# --- Install for each shell --- #

installed=0
skipped=0
denied=0

for shellName in "${targetShells[@]}"; do
  configFile="$(getShellConfig "${shellName}")"
  friendlyConfigPath="$(collapseTilde "${configFile}")"

  if [[ -f "${configFile}" ]] && grep -qF 'hooks/path.sh' "${configFile}"; then
    logInfo "Source line already present in ${friendlyConfigPath}"
    ((++skipped))
    continue
  fi

  logInfo "Adding hook source line to ${friendlyConfigPath}"

  printf '\n  %s\n\n' "${sourceLine}"
  if yesNo "The script wants to add this line to ${friendlyConfigPath}?"; then
    mkdir -p "$(dirname "${configFile}")"
    printf '\n%s\n' "${sourceLine}" >>"${configFile}"
    logSuccess "Added source line to ${friendlyConfigPath}"
    ((++installed))
  else
    ((++denied))
  fi
done

echo
if ((installed)); then
  logSuccess "Installed for ${installed} shell(s). Restart your shell to apply."
fi
if ((skipped)); then
  logInfo "Skipped ${skipped} shell(s) (already installed)"
fi
if ((denied)); then
  logWarning "Add the source line manually for ${denied} shell(s) to enable the hook"
fi
