#!/usr/bin/env bash

mkdir -p "${SCRIPTS_DIR:-..}/bin" &>/dev/null

for project in $(fd.sh . -d 1 --type d | tr -d '/'); do
  (
    cd "${project}" || true
    bun install --silent
    bun compile >/dev/null && mv "${project}" "${SCRIPTS_DIR:-..}/bin/" &&
      log-success "Compiled ${project} successfully!"
  )
done
