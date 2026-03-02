#!/usr/bin/env bash

mkdir -p "${SCRIPTS_DIR:-..}/bin" &>/dev/null

for file in $(fd.sh --no-ignore -e ts); do
  output="$(strip-ext "${file}" ts)"
  deno compile -o "${SCRIPTS_DIR}/bin/${output}" --quiet -A "${file}" &&
    log-success "Compiled ${output} successfully!"
done
