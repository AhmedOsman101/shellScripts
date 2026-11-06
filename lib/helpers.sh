#!/usr/bin/env bash
#
# --- SCRIPT SIGNATURE --- #
#
#  ▄▄                  ▄▄▄▄                                                                  ▄▄
#  ██                  ▀▀██                                                                  ██
#  ██▄████▄   ▄████▄     ██      ██▄███▄    ▄████▄    ██▄████  ▄▄█████▄            ▄▄█████▄  ██▄████▄
#  ██▀   ██  ██▄▄▄▄██    ██      ██▀  ▀██  ██▄▄▄▄██   ██▀      ██▄▄▄▄ ▀            ██▄▄▄▄ ▀  ██▀   ██
#  ██    ██  ██▀▀▀▀▀▀    ██      ██    ██  ██▀▀▀▀▀▀   ██        ▀▀▀▀██▄             ▀▀▀▀██▄  ██    ██
#  ██    ██  ▀██▄▄▄▄█    ██▄▄▄   ███▄▄██▀  ▀██▄▄▄▄█   ██       █▄▄▄▄▄██     ██     █▄▄▄▄▄██  ██    ██
#  ▀▀    ▀▀    ▀▀▀▀▀      ▀▀▀▀   ██ ▀▀▀      ▀▀▀▀▀    ▀▀        ▀▀▀▀▀▀      ▀▀      ▀▀▀▀▀▀   ▀▀    ▀▀
#                                ██
#
# --- DESCRIPTION --- #
# A collection of helper functions
# - logging shims (logDebug/.../logError), yesNo prompt, terminal line erasing
# - validation: isInt/isPositiveInt/isFloat/... and has-bash-version guard
# - quoting: shellQuote/humanQuote and array-join variants
# - hashing: hasher over stdin, a string, or a file (xxh3 -> sha1 fallback)
# - touch wrapper creating parent dirs; supportsColor honoring NO_COLOR/CI/_TTY_OK
# --- END SIGNATURE --- #

# shellcheck source=./loggers.sh
source "$(include "lib/loggers.sh")"
# ---  Main script logic --- #

# Returns stdin (no arguments, or first argument "-") or the joined arguments.
# Stdin is streamed unchanged so binary data such as NUL bytes survives;
# callers that capture the output in "$(...)" still lose NULs, because bash
# strings cannot contain them.
input() {
  if [[ $# -eq 0 || $1 == "-" ]]; then
    # Stream instead of capturing: a variable would drop NUL bytes.
    command cat
  else
    # Join the arguments and terminate with one newline.
    printf '%s' "$*"
  fi
}

logDebug() {
  printMagenta "[DEBUG] $(input "$@")"
}

logSuccess() {
  colorOnlyPrefix printGreen "SUCCESS" "$(input "$@")"
}

logInfo() {
  colorOnlyPrefix printPurple "INFO" "$(input "$@")"
}

logWarning() {
  colorOnlyPrefix printYellow "WARNING" "$(input "$@")" 2
}

logError() {
  colorOnlyPrefix printRed "ERROR" "$(input "$@")" 2

  # Exit with failure code
  exit 1
}

logSafeError() {
  colorOnlyPrefix printRed "ERROR" "$(input "$@")" 2
}

terminate() {
  local msg="${1:-Program terminated!}"
  logInfo "${msg}"
  exit 0
}

# NOTE: the integer/float validators accept only an optional '-' (5 and -5
# match, +5 does not); zero counts as positive for the isPositive* variants.
isInt() { [[ "$1" =~ ^-?[0-9]+$ ]]; }
isPositiveInt() { [[ "$1" =~ ^[0-9]+$ ]]; }
isNegativeInt() { [[ "$1" =~ ^- ]] && isInt "$1"; }

isFloat() { [[ "$1" =~ ^-?([0-9]*\.[0-9]+|[0-9]+)$ ]]; }
isPositiveFloat() { [[ "$1" =~ ^([0-9]*\.[0-9]+|[0-9]+)$ ]]; }
isNegativeFloat() { [[ "$1" =~ ^- ]] && isFloat "$1"; }

isPositive() { isPositiveFloat "$1"; }
isNegative() { isNegativeFloat "$1"; }

isInteractiveShell() {
  [[ -t 0 ]] && [[ -t 1 ]] && ps -o stat= -p "${PPID}" | grep -q 's'
}

eraseLine() {
  n="${1:-1}"
  isPositiveInt "${n}" || return 1

  for ((i = 0; i < n; i++)); do
    printf '\r'
    printf '\e[1A'
    printf '\e[2K'
  done
}

mapColor() {
  local color="$1"
  local -A colors=(
    [black]=0
    [red]=1
    [green]=2
    [yellow]=3
    [blue]=4
    [magenta]=5
    [cyan]=6
    [white]=7
    [gray]=8
    [grey]=8
  )

  if [[ -v "colors[${color}]" ]]; then
    echo "3${colors[${color}]}"
  fi
}

# Returns 0 if colors should be enabled, 1 otherwise
supportsColor() {
  # Explicit opt-out (standard)
  [[ -n "${NO_COLOR}" ]] && return 1

  # CI environments usually want plain logs
  [[ -n "${CI}" ]] && return 1

  # Must be a TTY. Callers that format inside $(...) — where stdout is a
  # pipe by construction — evaluate beforehand with real fds and pass the
  # verdict via _TTY_OK instead.
  if [[ -n "${_TTY_OK:-}" ]]; then
    [[ "${_TTY_OK}" == "1" ]] || return 1
  fi

  # TERM must support color
  case "${TERM:-}" in
    dumb | "") return 1 ;;
    *) return 0 ;;
  esac
}

shellQuote() {
  printf '%q' "$1"
}

shellQoute() { shellQuote "$1"; }

humanQuote() {
  local str=$1

  # Escape backslashes, double quotes, control chars
  str=${str//\\/\\\\}   # backslash
  str=${str//\"/\\\"}   # double quote
  str=${str//$'\n'/\\n} # newline
  str=${str//$'\t'/\\t} # tab
  str=${str//$'\r'/\\r} # carriage return

  # Quote if: contains whitespace, starts with dash, or contains only non-alnum chars
  if [[ "${str}" =~ [[:space:]] || "${str}" == -* || ! "${str}" =~ [a-zA-Z0-9_.-] ]]; then
    printf '"%s"' "${str}"
  else
    # Otherwise return normally
    printf '%s' "${str}"
  fi
}

humanQoute() { humanQuote "$1"; }

# Helper to join and quote an array for human display
shellJoinQuote() {
  local arr=("$@")
  local a result=""
  for a in "${arr[@]}"; do
    result+=$(shellQuote "${a}")" "
  done
  # remove trailing space
  printf '%s' "${result%" "}"
}

shellJoinHumanQuote() {
  local arr=("$@") result="" a
  for a in "${arr[@]}"; do
    result+=$(humanQuote "${a}")" "
  done
  printf '%s' "${result%" "}"
}

has-bash-version() {
  if ((BASH_VERSINFO[0] < $1 || BASH_VERSINFO[1] < $2)); then
    log-error "This script requires Bash v$1.$2 or later, you have Bash v${BASH_VERSION}"
  fi
}

yesNo() {
  local answer prompt="$1"
  printf '%b' "${prompt} [Y/n] "
  read -r answer </dev/tty

  [[ ! "${answer}" =~ ^[nN]$ ]]
}

# Hashes stdin, a string argument, or a file argument, printing
# "<hash>  <name>" in coreutils format. Picks xxh3sum, then xxhsum -H3,
# then sha1sum.
#
# stdin is streamed straight into the hash command because bash variables
# cannot hold NUL bytes; string/file arguments are captured normally.
# Returns 1 when a string argument is empty.
#   hasher "some text"
#   hasher /path/to/file
#   printf '%s' "some text" | hasher -
hasher() {
  local str="" cmd=() isFile=false

  if command -v xxh3sum &>/dev/null; then
    cmd+=(xxh3sum)
  elif command -v xxhsum &>/dev/null; then
    # xxhsum expects -H3 to select xxh3; keep as separate token
    cmd+=(xxhsum -H3)
  else
    cmd+=(sha1sum)
  fi

  # Stream stdin raw so NUL separators survive (a variable would drop them).
  if [[ $# -eq 0 || $1 == "-" ]]; then
    "${cmd[@]}"
    return
  fi

  str="$*"
  [[ -z "${str}" ]] && return 1
  [[ -e "${str}" && -r "${str}" && ! -d "${str}" ]] && isFile=true

  if ${isFile}; then
    "${cmd[@]}" "${str}"
  else
    "${cmd[@]}" - <<<"${str}"
  fi
}
