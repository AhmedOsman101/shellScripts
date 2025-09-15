#!/usr/bin/env bash

# ---  Main script logic --- #
printer() {
  local color="$1"
  local str="$2"
  local noNewline="${3:-false}"

  tput setaf "${color}"

  if [[ "${noNewline}" == "true" ]]; then
    echo -en "${str}"
  else
    echo -e "${str}"
  fi

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
