#!/usr/bin/env bash

set -euo pipefail

if [[ $# -eq 0 ]]; then
  directory=$(
    (eza "${TUCKR_DIR}" \
      --color=always \
      --only-dirs \
      --icons=always \
      --long \
      --no-time \
      --no-user \
      --sort name \
      --no-permissions \
      --no-filesize |
      gum filter \
        --indicator.background="" \
        --placeholder="Search..." \
        --header="Choose a config directory" \
        --fuzzy |
      cut -d " " -f 2-) || echo "${PWD}"
  )

else
  directory=$1
fi

echo "${TUCKR_DIR}/${directory}/.config"
