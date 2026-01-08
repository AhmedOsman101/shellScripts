#!/usr/bin/env bash

# ---  Main script logic --- #
sanitizedPrint() {
  local str="$1"
  str=${str//\\n/$'\n'}
  str=${str//\\t/$'\t'}
  str=${str//\\a/$'\a'}
  printf '%s' "${str}"
}

# Convert hex to RGB
hex_to_rgb() {
  local hex r g b
  hex=$1

  if [[ ! "${hex}" =~ ^#[0-9A-Fa-f]{3}$ && ! "${hex}" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
    log-error "Invalid hex color"
    return 1
  fi

  # Remove the '#' symbol
  hex="${hex#"#"}"

  if ((${#hex} == 3)); then
    # short form hex (#eee)
    r="${hex:0:1}${hex:0:1}"
    g="${hex:1:1}${hex:1:1}"
    b="${hex:2:1}${hex:2:1}"
  else
    # Long form hex (#ff00aa)
    r="${hex:0:2}" # from index 0 take 2
    g="${hex:2:2}" # from index 2 take 2
    b="${hex:4:2}" # from index 4 take 2
  fi

  # Convert hex to decimal
  r=$((16#${r})) || log-error "Invalid hex color"
  g=$((16#${g})) || log-error "Invalid hex color"
  b=$((16#${b})) || log-error "Invalid hex color"

  echo "${r} ${g} ${b}"
}

printer() {
  local color="$1"
  local str="$2"
  local noNewline="${3:-false}"

  if supportsColor; then
    tput setaf "${color}"
  fi

  sanitizedPrint "${str}"
  [[ "${noNewline}" != "true" ]] && printf '\n'

  tput sgr0
}

printBlack() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 0 "${str}" true
  else
    str="$(input "$@")"
    printer 0 "${str}"
  fi
}

printRed() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 1 "${str}" true
  else
    str="$(input "$@")"
    printer 1 "${str}"
  fi
}

printGreen() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 2 "${str}" true
  else
    str="$(input "$@")"
    printer 2 "${str}"
  fi
}

printYellow() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 3 "${str}" true
  else
    str="$(input "$@")"
    printer 3 "${str}"
  fi
}

printBlue() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 4 "${str}" true
  else
    str="$(input "$@")"
    printer 4 "${str}"
  fi
}

printMagenta() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 5 "${str}" true
  else
    str="$(input "$@")"
    printer 5 "${str}"
  fi
}

printCyan() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 6 "${str}" true
  else
    str="$(input "$@")"
    printer 6 "${str}"
  fi
}

printWhite() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 7 "${str}" true
  else
    str="$(input "$@")"
    printer 7 "${str}"
  fi
}

printGray() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 8 "${str}" true
  else
    str="$(input "$@")"
    printer 8 "${str}"
  fi
}

printBrightRed() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 9 "${str}" true
  else
    str="$(input "$@")"
    printer 9 "${str}"
  fi
}

printBrightGreen() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 10 "${str}" true
  else
    str="$(input "$@")"
    printer 10 "${str}"
  fi
}

printBrightYellow() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 11 "${str}" true
  else
    str="$(input "$@")"
    printer 11 "${str}"
  fi
}

printBrightBlue() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 12 "${str}" true
  else
    str="$(input "$@")"
    printer 12 "${str}"
  fi
}

printBrightMagenta() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 13 "${str}" true
  else
    str="$(input "$@")"
    printer 13 "${str}"
  fi
}

printBrightCyan() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 14 "${str}" true
  else
    str="$(input "$@")"
    printer 14 "${str}"
  fi
}

printBrightWhite() {
  local str
  if [[ "$1" == "-n" ]]; then
    shift
    str="$(input "$@")"
    printer 15 "${str}" true
  else
    str="$(input "$@")"
    printer 15 "${str}"
  fi
}

printPurple() {
  printHex "${U_PURPLE}" "$@"
}

printRGB() {
  local rgb r g b noNewLine=0
  (($# < 1)) && log-error "Missing color code"

  rgb=$1
  shift
  read -r r g b < <(echo "${rgb}")

  isUnsignedInt "${r}" || log-error "Invalid Red code"
  isUnsignedInt "${g}" || log-error "Invalid Green code"
  isUnsignedInt "${b}" || log-error "Invalid Blue code"

  if [[ "$1" == "-n" ]]; then
    shift
    noNewLine=1
  fi

  str="$(input "$@")"

  if supportsColor; then
    printf "%b" "\e[38;2;${r};${g};${b}m"
    sanitizedPrint "${str}"
    tput sgr0
  else
    sanitizedPrint "${str}"
  fi

  ((noNewLine)) || printf '\n'
}

printHex() {
  local hex rgb
  hex=$1
  shift
  rgb="$(hex_to_rgb "${hex}")" || log-error "Invalid hex color"
  printRGB "${rgb}" "$@"
}

# colorOnlyPrefix "<COLOR_FUNC>" "<LEVEL>" "<MESSAGE>" [FD]
colorOnlyPrefix() {
  local colorFunc level message fd
  colorFunc="$1"
  level="$2"
  message="$3"
  fd="${4:-1}"

  ${colorFunc} -n "[${level}]" >&"${fd}"
  sanitizedPrint " ${message}\n" >&"${fd}"
}
