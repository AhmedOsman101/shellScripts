# shellcheck disable=SC2046,SC2148
# Formats only the staged files
pnpm exec biome check --fix --no-errors-on-unmatched $(git diff --cached --name-only --diff-filter=ACMR | sed 's| |\\ |g' | paste -sd' ' -)

# Adds staged files again (to include the new formatter changes)
git add $(git diff --cached --name-only --diff-filter=ACMR)
