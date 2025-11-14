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

logInfo() {
  local str="$(input "$@")"
  printPurple "[INFO] ${str}"
}

logWarning() {
  local str="$(input "$@")"
  printYellow "[WARNING] ${str}"
}

logError() {
  local str="$(input "$@")"
  printRed "[ERROR] ${str}" 1>&2

  # Exit with failure code
  exit 1
}

logSafeError() {
  local str="$(input "$@")"
  printRed "[ERROR] ${str}" 1>&2
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
    . /etc/os-release
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
      logError "Unsupported distribution: ${PRETTY_NAME}" >&2
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

isInt() { [[ $1 =~ ^[+-]?[0-9]+$ ]]; }
isUnsignedInt() { [[ "$1" != -* && "$1" =~ ^[0-9]+$ ]]; }

isFloat() { [[ $1 =~ ^[+-]?([0-9]*\.[0-9]+|[0-9]+)$ ]]; }
isUnsignedFloat() { [[ "$1" != -* && $1 =~ ^([0-9]*\.[0-9]+|[0-9]+)$ ]]; }

# NOTE: zero is considered positive
isPositive() {
  local num="$1"
  [[ -z "${num}" ]] && return 1
  isUnsignedFloat "${num}" || return 1
}

isNegative() {
  local num="$1"
  [[ -z "${num}" ]] && return 1
  isFloat "${num}" || return 1
  [[ $(echo "${num} < 0" | bc -l) -eq 1 ]]
}

isInteractiveShell() {
  [[ -t 0 ]] && [[ -t 1 ]] && ps -o stat= -p "${PPID}" | grep -q 's'
}

benchmark() {
  local start=$(date +%s.%N)

  local iters="$1"
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
      printf "runs: %d\navg: %.6fs\nmin: %.6fs\nmax: %.6fs\n", NR, sum / NR, min, max
    }
  ' "${tmp}"

  echo "total: $(sec2time "${elapsed}" --short)"
}

eraseLine() {
  n="${1:-1}"
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
    echo "${colors[${color}]}"
  else
    return 1
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

randstr() {
  local len="${1:-16}"
  base64 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c "${len}"
  printf '\n'
}
