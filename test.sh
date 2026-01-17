#!/usr/bin/env bash

set -eo pipefail
trap 'exit 1' SIGUSR1
eval "$(include "lib/helpers.sh")"

# ---  Main script logic --- #
echo one two three >file.txt

printPurple '❯ temp.sh one two three'
temp.sh one two three

printPurple '❯ temp.sh "one two" three'
temp.sh "one two" three

printPurple '❯ temp.sh <(echo one two three)'
temp.sh <(echo one two three)

printPurple '❯ temp.sh <(echo "one two" three)'
temp.sh <(echo "one two" three)

printPurple '❯ temp.sh < <(echo one two three)'
temp.sh < <(echo one two three)

printPurple '❯ temp.sh < <(echo "one two" three)'
temp.sh < <(echo "one two" three)

printPurple '❯ temp.sh <<<"one two three"'
temp.sh <<<"one two three"

printPurple '❯ echo one two three | temp.sh'
echo one two three | temp.sh

printPurple '❯ echo "one two" three | temp.sh'
echo "one two" three | temp.sh

printPurple '❯ temp.sh <file.txt'
temp.sh <file.txt
