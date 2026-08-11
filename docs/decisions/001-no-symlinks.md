# ADR 001: No Symlinks — Repo is Source of Truth

## Status

Accepted

## Context

`init.sh` previously created symlinks for every executable script in the
repository into a flat directory (`~/.local/bin/scripts`), making them
globally available on `PATH`. This approach had several problems:

- **Namespace collisions** — two scripts with the same basename in different
  subdirectories silently clobbered each other (`python/foo.sh` vs
  `bash/foo.sh`).
- **Dangling symlinks** — deleting or renaming a script in the source repo
  left a broken symlink in the destination.
- **Stale state** — running `init.sh` removed only symlinks that were still
  executable, missing dangling ones.
- **Sudo dependency** — symlink operations required root for a user-owned
  directory.

## Decision

Remove all symlink creation. The repository path is the source of truth.
Users clone the repo wherever they want, set `SCRIPTS_DIR` to that path,
and scripts run directly from the repo. The only remaining problem is
getting the script directories onto `PATH`.

## Consequences

- `init.sh` no longer needs `sudo` for any operation.
- `DESTINATION_DIR` variable is removed entirely.
- No more flat-namespace collision problem (prevented at creation time
  by `mkscript` and `mkpython` — see ADR 004).
- No more dangling symlink cleanup needed.
- Users can move/rename the repo without breaking anything beyond updating
  `SCRIPTS_DIR`.
