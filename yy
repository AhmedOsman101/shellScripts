#!/usr/bin/zsh

tmp="$(mktemp -t "yazi-cwd.XXXXXX")"

yazi "$@" --cwd-file="${tmp}"

if cwd="$(cat -- "${tmp}")" && [[ -n ${cwd} ]] && [[ ${cwd} != "${PWD}" ]]; then
	builtin cd -- "${cwd}" || exit
fi

rm -f "${tmp}"
