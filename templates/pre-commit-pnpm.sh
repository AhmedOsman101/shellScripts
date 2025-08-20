#!/usr/bin/env bash
# shellcheck disable=SC2046,SC2148

gitRoot="$(git rev-parse --show-toplevel)"

cd "${gitRoot}" || exit 1

# Formats only the staged files
git diff --cached --name-only --diff-filter=ACMR | xargs -d '\n' pnpm exec biome check --fix --no-errors-on-unmatched

# Adds staged files again (to include the new formatter changes)
git diff --cached --name-only --diff-filter=ACMR | xargs -d '\n' git add

exit 0
