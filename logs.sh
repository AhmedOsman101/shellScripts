#!/usr/bin/env bash

## 31m: red, 32m: green, 33m: yellow, 34m: blue

log-info() {
	echo -e "\033[34m[INFO]: $1\033[0m"
}

log-success() {
	echo -e "\033[32m[SUCCESS]: $1\033[0m"
}

log-warning() {
	echo -e "\033[33m[WARNING]: $1\033[0m"
}

log-error() {
	echo -e "\033[31m[ERROR]: $1\033[0m" >&2
	exit 1
}
