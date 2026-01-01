#!/usr/bin/env bash
#
# --- SCRIPT SIGNATURE --- #
#
#        ▄▄                         ▄▄▄▄      ██     ▄▄▄▄                                              ▄▄
#        ██              ██        ██▀▀▀      ▀▀     ▀▀██                                              ██
#   ▄███▄██   ▄████▄   ███████   ███████    ████       ██       ▄████▄   ▄▄█████▄            ▄▄█████▄  ██▄████▄
#  ██▀  ▀██  ██▀  ▀██    ██        ██         ██       ██      ██▄▄▄▄██  ██▄▄▄▄ ▀            ██▄▄▄▄ ▀  ██▀   ██
#  ██    ██  ██    ██    ██        ██         ██       ██      ██▀▀▀▀▀▀   ▀▀▀▀██▄             ▀▀▀▀██▄  ██    ██
#  ▀██▄▄███  ▀██▄▄██▀    ██▄▄▄     ██      ▄▄▄██▄▄▄    ██▄▄▄   ▀██▄▄▄▄█  █▄▄▄▄▄██     ██     █▄▄▄▄▄██  ██    ██
#    ▀▀▀ ▀▀    ▀▀▀▀       ▀▀▀▀     ▀▀      ▀▀▀▀▀▀▀▀     ▀▀▀▀     ▀▀▀▀▀    ▀▀▀▀▀▀      ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#
#
# --- DESCRIPTION --- #
# Selects or specifies a configuration directory from TUCKR_DIR with interactive filtering
# --- DEPENDENCIES --- #
# - eza
# - fzf
# - fd | fdfind (fd-find)
# --- END SIGNATURE --- #

set -eo pipefail
trap 'exit 1' SIGUSR1

eval "$(include "lib/helpers.sh")"
eval "$(include "lib/cmdarg.sh")"
eval "$(include "check-deps")"

checkDeps "$0"
cmdarg_info "header" "$(get-desc "$0")"
cmdarg_parse "$@"
# ---  Main script logic --- #
cancelled=false

cd "${TUCKR_DIR}" || terminate
fzfPreview="$(
  cat <<'EOF'
item="$(echo {} | cut -d " " -f 2-)"
if [[ -d "${item}" ]]; then
  eza --all --tree -L 4 --color=always --icons=always --git --ignore-glob="node_modules|.turbo|dist|build|.next|.nuxt|.git|vendor" "${item}" | head -200
elif [[ "${item}" =~ \.(md|markdown)$ ]]; then
  if command -v mdcat 2>/dev/null; then
    mdcat {}
  elif command -v glow 2>/dev/null; then
    glow {}
  elif command -v bat 2>/dev/null; then
    bat --color=always --line-range :500 {}
  else
    cat {} | head -n 500
  fi
else
  bat --color=always --line-range :500 "${item}" || file "${item}"
fi
EOF
)"
if ((argc < 1)) || [[ -z "${argv[0]}" ]]; then
  app=$(
    eza \
      --only-dirs \
      --icons=always \
      --all -1 \
      --sort name |
      fzf --multi=1 \
        --preview="${fzfPreview}" \
        --layout=reverse \
        --preview-window='right:65%' |
      cut -d " " -f 2-
  ) || cancelled=true
else
  app="${argv[0]}"
fi

if "${cancelled}"; then
  eraseLine
  terminate "Nothing selected"
fi

fullpath="$(fd-by-depth "${app}" --hidden --type d --min-depth=2 --max-depth=4 "${TUCKR_DIR}/${app}" | tail -n 1)"
[[ -z "${fullpath}" ]] && fullpath="${TUCKR_DIR}/${app}"

echo "${fullpath}"
