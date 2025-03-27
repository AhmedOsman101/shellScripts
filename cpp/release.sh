#!/usr/bin/env bash

cppc --compile "$@"

mkdir "${SCRIPTS_DIR}/bin" &>/dev/null

fd --no-ignore -e out --exec mv {} "${SCRIPTS_DIR}/bin/{/.}"
