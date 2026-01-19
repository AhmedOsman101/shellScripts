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

eval "$(include "lib/loggers.sh")"
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
  local msg="${1:-Program terminated!}"
  logInfo "${msg}"
  exit 0
}

getDeps() {
  local file
  if [[ $# -ne 1 ]]; then
    logError "Invalid arguments, only a script name is accepted"
  else
    if [[ -f $1 ]]; then
      file=$1
    else
      file=$(command -v "$1")
    fi

    [[ ! -f ${file} ]] && logError "Script '${file}' was not found"
  fi

  sed -n '/# --- DEPENDENCIES --- #/,/# --- END SIGNATURE --- #/{/\# - /p;}' "${file}" |
    sed 's|# - ||g' |
    grep -v " --- " || echo "x-none"
}

getPackageManager() {
  local installCmd pkgManager

  # Parse /etc/os-release to determine the distribution
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
  else
    logError "/etc/os-release not found."
  fi

  # Determine package manager and install command
  case "${ID}" in
  debian | ubuntu | linuxmint | pop | raspbian | kali | neon | elementary)
    # For Debian/Ubuntu-based distros, check for nala helpers
    if command -v nala &>/dev/null; then
      pkgManager="nala"
      installCmd="sudo -A nala install"
    else
      pkgManager="apt"
      installCmd="sudo -A apt install"
    fi
    ;;
  fedora | rhel | almalinux | rocky | ol)
    # Fedora/RHEL-based distros (modern)
    pkgManager="dnf"
    installCmd="sudo -A dnf install"
    ;;
  centos)
    # CentOS (check for legacy versions)
    if [[ "${VERSION_ID}" == 7* ]]; then
      pkgManager="yum" # Legacy CentOS 7
      installCmd="yum install"
    else
      pkgManager="dnf" # CentOS 8+/Stream
      installCmd="dnf install"
    fi
    ;;
  opensuse* | sled | sles)
    # openSUSE/SUSE-based distros
    pkgManager="zypper"
    installCmd="sudo -A zypper install"
    ;;
  arch | manjaro | endeavouros | archcraft)
    # For Arch-based distros, check for AUR helpers
    if command -v paru &>/dev/null; then
      pkgManager="paru"
      installCmd="paru -S --noconfirm"
    elif command -v yay &>/dev/null; then
      pkgManager="yay"
      installCmd="yay -S --noconfirm"
    else
      pkgManager="pacman"
      installCmd="sudo -A pacman -S --noconfirm"
    fi
    ;;
  void)
    # Void Linux
    pkgManager="xbps"
    installCmd="sudo -A xbps-install -S"
    ;;
  alpine)
    # Alpine Linux
    pkgManager="apk"
    installCmd="sudo -A apk add"
    ;;
  amzn)
    # Amazon Linux
    if [[ "${VERSION_ID}" == 2 ]]; then
      pkgManager="yum" # Amazon Linux 2
      installCmd="yum install"
    else
      pkgManager="dnf" # Amazon Linux 2023+
      installCmd="dnf install"
    fi
    ;;
  gentoo)
    # Gentoo Linux (source-based)
    pkgManager="emerge"
    installCmd="sudo -A emerge"
    ;;
  *)
    # Fallback to ID_LIKE for derivatives
    case "${ID_LIKE}" in
    *debian* | *ubuntu*)
      # For Debian/Ubuntu-based distros, check for nala helpers
      if command -v nala &>/dev/null; then
        pkgManager="nala"
        installCmd="sudo -A nala install"
      else
        pkgManager="apt"
        installCmd="sudo -A apt install"
      fi
      ;;
    *fedora* | *rhel*)
      pkgManager="dnf"
      installCmd="sudo -A dnf install"
      ;;
    *suse*)
      pkgManager="zypper"
      installCmd="sudo -A zypper install"
      ;;
    *arch*)
      # For Arch-based distros, check for AUR helpers
      if command -v paru &>/dev/null; then
        pkgManager="paru"
        installCmd="sudo -A paru -S --noconfirm"
      elif command -v yay &>/dev/null; then
        pkgManager="yay"
        installCmd="sudo -A yay -S --noconfirm"
      else
        pkgManager="pacman"
        installCmd="sudo -A pacman -S --noconfirm"
      fi
      ;;
    *)
      logError "Unsupported distribution: ${PRETTY_NAME:-${NAME:-Unknown}}" >&2
      ;;
    esac
    ;;
  esac

  echo "${pkgManager}:${installCmd}"
}

Trim() {
  local str="$(input "$@")"
  [[ -z ${str} ]] && printf '' && exit 0
  echo "${str}" | sed -e "s|^[[:space:]]*||" -e "s|[[:space:]]*$||"
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

benchmark() {
  local start=$(date +%s.%N)

  local iters="$1"
  isPositiveInt "${iters}" || return 1
  shift

  tmp="$(mktemp)"
  trap 'rm -rf $tmp' EXIT

  loop -n "${iters}" "command time -f '%e' -o ${tmp} -a $* >/dev/null 2>&1"

  local end=$(date +%s.%N)
  local elapsed="$(bc <<<"${end} - ${start}")"

  awk '
    {
      sum+=$1
      if(NR == 1 || $1 < min) min=$1
      if(NR == 1 || $1 > max) max=$1
      }
      END {
      printf "runs: %d\navg: %.6fs\nmin: %.6fs\nmax: %.6fs\n", NR / 2, sum / NR, min, max
    }
  ' "${tmp}"

  echo "total: $(sec2time "${elapsed}" --short)"
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

has-bash-version() {
  if ((BASH_VERSINFO[0] < $1 || BASH_VERSINFO[1] < $2)); then
    log-error "This script requires Bash v$1.$2 or later, you have Bash v${BASH_VERSION}"
  fi
}
