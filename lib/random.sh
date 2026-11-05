#!/usr/bin/env bash
#
# --- SCRIPT SIGNATURE --- #
#
#                                     ▄▄                                          ▄▄
#                                     ██                                          ██
#  ██▄████   ▄█████▄  ██▄████▄   ▄███▄██   ▄████▄   ████▄██▄            ▄▄█████▄  ██▄████▄
#  ██▀       ▀ ▄▄▄██  ██▀   ██  ██▀  ▀██  ██▀  ▀██  ██ ██ ██            ██▄▄▄▄ ▀  ██▀   ██
#  ██       ▄██▀▀▀██  ██    ██  ██    ██  ██    ██  ██ ██ ██             ▀▀▀▀██▄  ██    ██
#  ██       ██▄▄▄███  ██    ██  ▀██▄▄███  ▀██▄▄██▀  ██ ██ ██     ██     █▄▄▄▄▄██  ██    ██
#  ▀▀        ▀▀▀▀ ▀▀  ▀▀    ▀▀    ▀▀▀ ▀▀    ▀▀▀▀    ▀▀ ▀▀ ▀▀     ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#
# --- DESCRIPTION --- #
# Random generation helpers
# - `randStr [length] [symbols]`  : alphanumeric string from /dev/urandom
# - `randRange [min] [max]`       : unbiased integer, inclusive
# - `randWords [count]`           : dictionary words, gibberish fallback
#
# The public generators print their result to stdout and return non-zero on
# bad input. Optional arguments fall back to the defaults shown above.
# --- END SIGNATURE --- #

# shellcheck source=./helpers.sh
source "$(include 'lib/helpers.sh')"

# ---  Main script logic --- #

# Prints <value> as a base-10 integer, keeping its sign. The explicit 10#
# prevents values like 08 from being parsed as invalid octal.
__norm_signed() {
  local sign=1 v=$1
  [[ "${v}" == -* ]] && {
    sign=-1
    # Remove leading negative sign
    v=${v#-}
  }
  # multiply by sign to normalize the value
  printf '%d' $((sign * 10#${v}))
}

# Prints the path to a cached word list built from <dict> and filtered by the
# extended regex <pattern>. Returns 1 (printing nothing) if no cache could be
# produced, e.g. the dictionary is unreadable or nothing matches.
__randwords_pool() {
  local dict=$1 pattern=$2
  local cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/randwords"
  command mkdir -p -- "${cache_dir}" 2>/dev/null || return 1

  local key pool stamp fp tmp
  # Cache key covers both inputs; the stamp below holds the dictionary's
  # mtime:size so edits to the dictionary trigger a rebuild.
  # shellcheck disable=SC2119
  key=$(printf '%s\0%s' "${dict}" "${pattern}" | hasher | awk '{print $1}')
  pool="${cache_dir}/${key}.pool"
  stamp="${cache_dir}/${key}.stamp"

  fp=$(stat -Lc '%Y:%s' -- "${dict}" 2>/dev/null) || return 1

  if [[ -f ${pool} && -f ${stamp} && $(<"${stamp}") == "${fp}" ]]; then
    printf '%s' "${pool}"
    return 0
  fi

  tmp=$(mktemp -- "${cache_dir}/.${key}.XXXXXX") || return 1
  trap 'command rm -f -- $tmp' EXIT
  if ! LC_ALL=C command grep -E -- "${pattern}" "${dict}" >"${tmp}"; then
    return 1
  fi

  # Write the pool before the stamp, so a visible stamp always points at a
  # usable pool. The opposite race (fresh pool, stale stamp) only causes a
  # harmless rebuild.
  mv -f -- "${tmp}" "${pool}"
  printf '%s\n' "${fp}" >"${stamp}"
  printf '%s' "${pool}"
}

# Prints an integer in the inclusive range [min, max]. Defaults to [1, 10].
# Rejection sampling keeps the result unbiased. Returns 1 on invalid input or
# when the range cannot be sampled (i.e. > 32768 without SRANDOM).
randRange() {
  local min max
  min=$(__norm_signed "${1:-1}")
  max=$(__norm_signed "${2:-10}")
  isInt "${min}" && isInt "${max}" || return 1
  ((min <= max)) || return 1

  local range=$((max - min + 1)) r limit
  if [[ -n ${SRANDOM+set} ]]; then
    # SRANDOM (bash 5.1+) is 32-bit; discard the tail that would bias the modulo.
    limit=$((4294967296 / range * range)) # 2^32
    while :; do
      r=${SRANDOM}
      ((r < limit)) && break
    done
  else
    # RANDOM is only 15-bit, which caps the usable range.
    ((range <= 32768)) || return 1
    limit=$((32768 / range * range))
    while :; do
      r=${RANDOM}
      ((r < limit)) && break
    done
  fi
  printf '%d' $((min + r % range))
}

# Prints a random string of <length> characters (default 16). The alphabet is
# A-Za-z0-9, plus !@#$%&*?^+ when <symbols> is true. Characters are drawn
# uniformly by filtering /dev/urandom, so the extra read bytes only ensure the
# requested length is reached after filtering.
randStr() {
  local len="${1:-16}" symbols="${2:-false}" pattern='A-Za-z0-9'
  isPositiveInt "${len}" || return 1
  len=$((10#${len}))
  ((len > 0)) || return 1

  local raw
  # ~62/256 (or ~72/256 with symbols) of bytes survive the filter, so this
  # reads enough for ~2*len characters on average, then keeps the first len.
  ${symbols} && pattern+="!@#$%&*?^+"
  raw=$(head -c $((len * 8 + 128)) /dev/urandom | LC_ALL=C tr -dc "${pattern}")
  printf '%s' "${raw:0:${len}}"
}

# Prints <count> space-separated words (default 1), preferring a cached pool
# from the system dictionary. Falls back to random 6-letter gibberish when no
# dictionary is available or the pool has fewer than <count> words.
randWords() {
  local count="${1:-1}" out=""

  (isPositiveInt "${count}" && ((10#${count} > 0)) ) ||
    log-error "Number of words must be a positive integer"
  count=$((10#${count}))

  # Keep passphrase words short and alphabetic: easy to read and type.
  local pattern='^[A-Za-z]{4,8}$'
  local dict pool="" nlines=0

  # Honour an explicit dictionary first, then try common system locations.
  for dict in "${RANDWORDS_DICT:-}" /usr/share/dict/{words,american-english,british-english}; do
    [[ -n ${dict} && -r ${dict} ]] || continue
    pool=$(__randwords_pool "${dict}" "${pattern}") && [[ -n ${pool} ]] && break
    pool=""
  done

  # Check the pool size first so shuf never returns fewer words than asked.
  if [[ -n ${pool} ]]; then
    nlines=$(wc -l <"${pool}")
    if ((nlines >= count)); then
      out=$(shuf -n "${count}" -- "${pool}" | tr '\n' ' ')
    fi
  fi

  # Fallback when there is no usable dictionary/pool: 6-character alphanumerics.
  if [[ -z ${out} ]]; then
    local i
    for ((i = 0; i < count; i++)); do out+="$(randStr 6) "; done
  fi

  printf '%s' "${out% }"
}
