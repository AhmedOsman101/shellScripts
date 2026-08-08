#!/usr/bin/env bash

clangc --compile "$@"

mkdir -p "${SCRIPTS_DIR}/bin" &>/dev/null

fd.sh --no-ignore -e out --exec mv {} "${SCRIPTS_DIR}/bin/{/.}"
