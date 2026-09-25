#!/usr/bin/env fish
#
# --- SCRIPT SIGNATURE --- #
#
#                                ▄▄                            ▄▄
#                        ██      ██                            ██
#  ██▄███▄    ▄█████▄  ███████   ██▄████▄            ▄▄█████▄  ██▄████▄
#  ██▀  ▀██   ▀ ▄▄▄██    ██      ██▀   ██            ██▄▄▄▄ ▀  ██▀   ██
#  ██    ██  ▄██▀▀▀██    ██      ██    ██             ▀▀▀▀██▄  ██    ██
#  ███▄▄██▀  ██▄▄▄███    ██▄▄▄   ██    ██     ██     █▄▄▄▄▄██  ██    ██
#  ██ ▀▀▀     ▀▀▀▀ ▀▀     ▀▀▀▀   ▀▀    ▀▀     ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#  ██
#
# --- DESCRIPTION --- #
# Fish port of hooks/path.sh — adds directories containing executable scripts to PATH.
# Sourced (not executed) from fish config:
#   test -s "$SCRIPTS_DIR/hooks/path.fish"; and source "$SCRIPTS_DIR/hooks/path.fish"
# --- DEPENDENCIES --- #
# - fd
# --- END SIGNATURE --- #

# Guard: SCRIPTS_DIR unset or missing -> silent no-op (no top-level return;
# fish `return` outside a function is an error, so gate the whole body).
# Locals stay inside this block; nothing leaks (functions intentionally
# avoided — `set -l` does not cross function boundaries).
if set -q SCRIPTS_DIR; and test -d "$SCRIPTS_DIR"
    set -l __cacheFile '/tmp/path-hook.cache'

    set -l __defaultExcludes '.git' '.venv' 'venv' 'node_modules' 'release.sh'

    set -l __userExcludes
    if set -q SCRIPTS_HOOK_EXCLUDE; and test -n "$SCRIPTS_HOOK_EXCLUDE"
        set __userExcludes (string split -n ' ' -- $SCRIPTS_HOOK_EXCLUDE)
    end

    set -l __fdExcludes
    for __pattern in $__defaultExcludes $__userExcludes
        test -n "$__pattern"; and set -a __fdExcludes --exclude "$__pattern"
    end

    # Validating the cache: rescan when missing/empty, or any dir is newer.
    set -l __needScan 0
    if not test -s "$__cacheFile"
        set __needScan 1
    else
        set -l __newer (find "$SCRIPTS_DIR" -type d -newer "$__cacheFile" -print -quit 2>/dev/null)
        if set -q __newer[1]
            set __needScan 1
        end
    end

    if test "$__needScan" -eq 1
        # No subshell-cd in fish: save and restore $PWD manually.
        set -l __cwd $PWD
        if cd "$SCRIPTS_DIR"
            fd --strip-cwd-prefix=always --no-ignore-vcs -t x . $__fdExcludes >"$__cacheFile" 2>/dev/null
            cd "$__cwd"
        end
    end

    if test -s "$__cacheFile"
        # Fish $PATH is a list, so `contains` replaces the ":$PATH:" dance.
        # ponytail: full re-read of cache per shell; mtime gate keeps it to one scan/session.
        while read -l __entry
            set -l __rel (string replace -r '^\./' '' -- "$__entry")
            test -n "$__rel"; or continue
            set -l __dir (path dirname -- "$SCRIPTS_DIR/$__rel")
            if not contains -- "$__dir" $PATH
                set -gx PATH $PATH "$__dir"
            end
        end <"$__cacheFile"
    end
end
