#!/usr/bin/env bash

mkdir "${SCRIPTS_DIR:-..}/bin" &>/dev/null
basedir="$(dirname $0)"
for file in $(fd --no-ignore -e ts); do
  output="$(strip-ext ${file} ts)"
  cd "$(dirname "${file}")" || log-error "Failed to find ${file}'s rootdir"
  deno compile --quiet "$(basename ${file})" -o "${output}" &&
    mv -f "${output}" "${SCRIPTS_DIR}/bin/" && {
    cd "${basedir}" || log-error "Failed to cd into basedir"
    log-success "Compiled ${output} successfully!"
  }
done
