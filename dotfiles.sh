#!/usr/bin/env bash

set -euo pipefail

if [[ $# -eq 0 ]]; then
  app=$(
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
        --placeholder="Search..." \
        --header="Choose a config directory" \
        --fuzzy |
      cut -d " " -f 2-) || echo "${PWD}"
  )

else
  app=$1
fi

fullpath="${TUCKR_DIR}/${app}/.config"

[[ -d "${fullpath}/${app}" ]] && fullpath="${fullpath}/${app}"

echo ${fullpath}
