#!/usr/bin/env bash

clangc --compile "$@"

mkdir -p "${SCRIPTS_DIR}/bin" &>/dev/null

fd --no-ignore -e out --exec mv {} "${SCRIPTS_DIR}/bin/{/.}"
