#!/usr/bin/env bash

logInfo() {
  tput setaf 4
  echo -e "[INFO]: $*"
  tput sgr0
}

logWarning() {
  tput setaf 3
  echo -e "[INFO]: $*"
  tput sgr0
}

logError() {
  # Print error message in red
  tput setaf 1

  echo -e "[ERROR]: $*" 1>&2
  tput sgr0

  # Exit with failure code
  exit 1
}

getDeps() {
  local file
  if [[ $# -ne 1 ]]; then
    logError "Invalid arguments, only a script name is accepted"
  else
    if [[ -f $1 ]]; then
      file=$1
    else
      file=$(which $1)
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
      installCmd="sudo -A paru -S --noconfirm"
    elif command -v yay &>/dev/null; then
      pkgManager="yay"
      installCmd="sudo -A yay -S --noconfirm"
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
  str=$(cat)
  [[ -z ${str} ]] && printf '' && exit 0
  echo "${str}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}
