#!/usr/bin/env bash
#
# --- SCRIPT SIGNATURE --- #
#
#                                ▄▄                            ▄▄
#                        ██      ██                            ██
#  ██▄███▄    ▄█████▄  ███████   ██▄████▄            ▄▄█████▄  ██▄████▄
#  ██▀  ▀██   ▀ ▄▄▄██    ██      ██▀   ██            ██▄▄▄▄ ▀  ██▀   ██
#  ██    ██  ▄██▀▀▀██    ██      ██    ██             ▀▀▀▀██▄  ██    ██
#  ███▄▄██▀  ██▄▄▄███    ██▄▄▄   ██    ██     ██     █▄▄▄▄▄██  ██    ██
#  ██ ▀▀▀     ▀▀▀▀ ▀▀     ▀▀▀▀   ▀▀    ▀▀     ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#  ██
#
# --- DESCRIPTION --- #
# Adds directories containing executable scripts to PATH
# --- DEPENDENCIES --- #
# - fd
# --- END SIGNATURE --- #

# ---  Main script logic --- #
[[ -n "${SCRIPTS_DIR}" ]] || return 0
[[ -d "${SCRIPTS_DIR}" ]] || return 0

__cacheFile="/tmp/path-hook.cache"

__defaultExcludes=(
  ".git"
  ".venv"
  "venv"
  "node_modules"
)

__userExcludes=()
if [[ -n "${SCRIPTS_HOOK_EXCLUDE}" ]]; then
  read -ra __userExcludes <<<"${SCRIPTS_HOOK_EXCLUDE}"
fi

__fdExcludes=()
for __pattern in "${__defaultExcludes[@]}" "${__userExcludes[@]}"; do
  __fdExcludes+=(--exclude "${__pattern}")
done

__needsRescan() {
  [[ -s "${__cacheFile}" ]] || return 0
  [[ -n "$(find "${SCRIPTS_DIR}" -type d -newer "${__cacheFile}" -print -quit 2>/dev/null)" ]]
}

__scan() {
  (
    cd "${SCRIPTS_DIR}" || return 1
    fd -t x . "${__fdExcludes[@]}" | sed 's|^|./|'
  ) >"${__cacheFile}" 2>/dev/null
}

# Validating the cache
__needsRescan && __scan

if [[ -s "${__cacheFile}" ]]; then
  declare -a __entries=()
  while IFS= read -r __line; do
    __entries+=("${__line}")
  done <"${__cacheFile}"

  for __entry in "${__entries[@]}"; do
    __rel="${__entry#./}"
    [[ -n "${__rel}" ]] || continue
    __abs="${SCRIPTS_DIR}/${__rel}"
    __dir="${__abs%/*}"

    if [[ ":${PATH}:" != *":${__dir}:"* ]]; then
      PATH="${PATH}:${__dir}"
    fi
  done
fi

# Store all used variables and functions
__vars=(__cacheFile __defaultExcludes __dir __fdExcludes __needsRescan __pattern __scan __userExcludes __rel __abs __entries __entry)
__functions=(__needsRescan __scan)

# Cleanup used variables and function to prevent leakage into the user's shell.
unset -f "${__functions[@]}"
unset "${__vars[@]}" __vars __functions

# Export the modified PATH variable
export PATH
