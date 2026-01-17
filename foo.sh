#!/usr/bin/env bash

set -eo pipefail
trap 'exit 1' SIGUSR1
eval "$(include "spin.sh")"
# ---  Main script logic --- #
spinnerStart
for i in {1..3}; do
  log-debug "${i}"
  sleep 1
done
spinnerEnd
exit 0
