#!/usr/bin/env bash
#
# --- SCRIPT SIGNATURE --- #
#
#                                                ▄▄                                ▄▄
#                                                ██                                ██
#  ██▄  ▄██  ▄▄█████▄   ▄█████▄   ▄████▄    ▄███▄██   ▄████▄             ▄▄█████▄  ██▄████▄
#   ██  ██   ██▄▄▄▄ ▀  ██▀    ▀  ██▀  ▀██  ██▀  ▀██  ██▄▄▄▄██            ██▄▄▄▄ ▀  ██▀   ██
#   ▀█▄▄█▀    ▀▀▀▀██▄  ██        ██    ██  ██    ██  ██▀▀▀▀▀▀             ▀▀▀▀██▄  ██    ██
#    ████    █▄▄▄▄▄██  ▀██▄▄▄▄█  ▀██▄▄██▀  ▀██▄▄███  ▀██▄▄▄▄█     ██     █▄▄▄▄▄██  ██    ██
#     ▀▀      ▀▀▀▀▀▀     ▀▀▀▀▀     ▀▀▀▀      ▀▀▀ ▀▀    ▀▀▀▀▀      ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#
#
# --- DESCRIPTION --- #
# Query VS Code extensions from its local data files
# - disabledExtensions: from state.vscdb (ItemTable key 'extensionsIdentifiers/disabled')
# - allExtensions / enabledExtensions: from ~/.vscode/extensions/extensions.json
# - Lists extension ids, sorted; missing file/db is fatal via log-error
# --- END SIGNATURE --- #

# ---  Main script logic --- #
__stateDb="${XDG_CONFIG_HOME:-${HOME}/.config}/Code/User/globalStorage/state.vscdb"
__extensionsJson="${HOME}/.vscode/extensions/extensions.json"

disabledExtensions() {
  [[ -f "${__stateDb}" ]] || log-error "VS Code state database not found: ${__stateDb}"

  sqlite3 -list "${__stateDb}" \
    "SELECT value FROM ItemTable WHERE key='extensionsIdentifiers/disabled'" |
    jq -r '.[].id' | sort
}

allExtensions() {
  [[ -f "${__extensionsJson}" ]] || log-error "VS Code extensions file not found: ${__extensionsJson}"

  jq -r '.[].identifier.id' "${__extensionsJson}" | sort
}

enabledExtensions() {
  comm -23 \
    <(allExtensions) \
    <(disabledExtensions)
}

unset __stateDb __extensionsJson &>/dev/null
