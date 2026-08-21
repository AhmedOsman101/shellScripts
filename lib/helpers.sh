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
# --- END SIGNATURE --- #

source "$(include "lib/loggers.sh")"
# ---  Main script logic --- #

input() {
  local str
  if [[ $# -eq 0 || $1 == "-" ]]; then
    # read from stdin
    str=$(cat)
  else
    # read the passed arguments
    str="$*"
  fi

  echo "${str}"
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
  local msg="${1:-'Program terminated!'}"
  logInfo "${msg}"
  exit 0
}

# NOTE: zero is considered positive
isInt() { [[ "$1" =~ ^[+-]?[0-9]+$ ]]; }
isPositiveInt() { [[ "$1" =~ ^[0-9]+$ ]]; }
isNegativeInt() { [[ "$1" =~ ^- ]] && isInt "$1"; }

isFloat() { [[ "$1" =~ ^[+-]?([0-9]*\.[0-9]+|[0-9]+)$ ]]; }
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

touch() {
  for file in "$@"; do
    if [[ ! -f "${file}" ]]; then
      local dir="$(dirname "${file}")"
      if [[ ! -d "${dir}" ]]; then
        if ! mkdir -p "${dir}"; then
          log-warning "Couldn't create parent directory, skipping file: ${file}"
          continue
        fi
      fi
    fi
    command touch "${file}"
  done
}

randStr() {
  local len="${1:-16}"
  isPositiveInt "${len}" || return 1
  ((len > 0)) || return 1

  # Secure random string using kernel RNG
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${len}"
  printf '\n'
}

randRange() {
  local min=${1:-1}
  local max=${2:-10}

  isInt "${min}" || return 1
  isInt "${max}" || return 1

  ((min <= max)) || return 1

  local range=$((max - min + 1))
  ((range <= 32768)) || return 1

  local limit=$((32768 / range * range))
  local r

  while :; do
    r=${RANDOM}
    ((r < limit)) && break
  done

  printf '%d\n' $((min + r % range))
}

randWords() {
  local count="$1"
  local dict="/usr/share/dict/words"
  isPositiveInt "${count}" || log-error "Number of words must be a positive integer"

  # Generate n words and join them with spaces
  if [[ -f "${dict}" ]]; then
    # Use the system dictionary if available
    shuf -n "${count}" "${dict}" | tr '\n' ' '
  else
    # Fallback: Efficient gibberish generation
    # 1. Read random bytes from urandom
    # 2. Filter to keep only lowercase letters
    # 3. Fold into lines of 6 characters (simulating word length)
    # 4. Take the requested number of 'words'
    # 5. Join them with spaces
    head -c $((count * 50)) /dev/urandom | tr -dc '[:lower:]' | fold -w 6 | head -n "${count}" | tr '\n' ' '
  fi
  printf '\n'
}

# Returns 0 if colors should be enabled, 1 otherwise
supportsColor() {
  # Explicit opt-out (standard)
  [[ -n "${NO_COLOR}" ]] && return 1

  # CI environments usually want plain logs
  [[ -n "${CI}" ]] && return 1

  # Must be a TTY
  [[ ! -t 1 && ! -t 2 ]] && return 1

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

# Detect a hashing command and return it as an array for safe exec
hasher() {
  if command -v xxh3sum &>/dev/null; then
    xxh3sum "$@"
  elif command -v xxhsum &>/dev/null; then
    # xxhsum expects -H3 to select xxh3; keep as separate token
    xxhsum -H3 "$@"
  else
    sha1sum "$@"
  fi
}
