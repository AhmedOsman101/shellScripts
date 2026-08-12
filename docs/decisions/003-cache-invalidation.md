# ADR 003: Hook Caches Results with mtime Invalidation

## Status

Accepted

## Context

The hook script (ADR 002) scans the repo for executable files on every
shell startup and adds each executable's containing directory to PATH.
A recursive `fd -t x` scan adds 50-100ms to shell startup time, which
compounds across nested shells, tmux panes, and editor integrated
terminals.

## Decision

Cache the scanned file list to `/tmp/path-hook.cache`. The cache
invalidates on directory mtime, not file mtime, and not `$SCRIPTS_DIR`'s
own mtime.

This distinction matters because the hook adds directories to PATH, not
individual files. Editing an existing script's contents doesn't change
its parent directory's mtime, so it shouldn't trigger a rescan. Adding
or removing an executable inside a directory does change that
directory's mtime, and that's exactly the case where PATH needs to
update. Checking only `$SCRIPTS_DIR`'s own mtime misses this: nested
directories can gain or lose executables without the top-level
directory's mtime changing at all.

On each run, `fd` walks `$SCRIPTS_DIR` for any directory newer than
the cache file, exiting on the first match instead of scanning every
directory. The hook calls `fd` directly (not `fd.sh`) to keep its
exclude logic local and self-contained. `--strip-cwd-prefix=always`
keeps cached paths relative to `SCRIPTS_DIR` (surviving moves), and
`--no-ignore-vcs` ensures `.gitignore` rules don't silently exclude
files the hook should include (the repo's ignore rules and the hook's
include rules are separate concerns):

```bash
#!/usr/bin/env bash

cacheFile="/tmp/path-hook.cache"

scan() {
  (
    cd "${SCRIPTS_DIR}" || return 1
    fd --strip-cwd-prefix=always --no-ignore-vcs -t x . "${fdExcludes[@]}"
  ) >"${cacheFile}" 2>/dev/null
}

needsRescan() {
  [[ -s "${cacheFile}" ]] || return 0
  [[ -n "$(find "${SCRIPTS_DIR}" -type d -newer "${cacheFile}" -print -quit 2>/dev/null)" ]]
}

needsRescan && scan

declare -a entries=()
while IFS= read -r line; do
  entries+=("${line}")
done < "${cacheFile}"
```

The cache lives in `/tmp` rather than `$XDG_CACHE_HOME`. It only needs
to last for one session: the first shell startup pays the scan cost,
every shell after that in the same session reads the cache, and a
reboot clears `/tmp` so the next session starts with a clean scan
instead of trusting a cache from a previous boot.

## Consequences

- Shell startup stays fast after the first scan in a session.
- Adding or removing an executable script triggers a rescan on the next
  shell start, because the containing directory's mtime changes.
- Editing a script's contents does not trigger a rescan, since it
  doesn't change the parent directory's mtime. This is correct: the
  hook cares about which directories to add to PATH, not about file
  contents.
- The cache doesn't survive a reboot, since `/tmp` is cleared. This is
  intentional: the cache is a session optimization, not a persistent
  store.
- Cached paths are relative to `SCRIPTS_DIR` (via
  `--strip-cwd-prefix=always`), so the cache stays valid even if the
  absolute location of `$SCRIPTS_DIR` changes.
- `.gitignore` rules do not filter the cache. The hook uses
  `--no-ignore-vcs` because the repo's ignore rules and the hook's
  include rules are separate concerns: a script in `bin/` might be
  gitignored but still belongs on PATH.
- The cache is read with a `while IFS= read` loop rather than `mapfile`,
  since `mapfile` is a bashism that zsh does not provide natively.
- Users can force a rescan by deleting the cache file:
  `rm /tmp/path-hook.cache`.
