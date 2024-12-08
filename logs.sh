#!/usr/bin/env bash

log_info() {
	echo -e "\033[32m[INFO]: $1\033[0m"
}

log_warning() {
	echo -e "\033[33m[WARNING]: $1\033[0m"
}

log_error() {
	echo -e "\033[31m[ERROR]: $1\033[0m" >&2
	exit 1
}
