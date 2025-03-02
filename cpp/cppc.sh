#!/usr/bin/env bash

cppc "$@"

fd --no-ignore -e out --exec mv {} "${SCRIPTS_DIR}/bin/{/.}"
