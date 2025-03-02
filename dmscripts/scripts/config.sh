#!/usr/bin/env bash
# shellcheck disable=SC2034
# This issue is ignored because it is part of a larger file that calls upon all variables listed

# To edit this file copy it to `${HOME}/.config/dmscripts/config`
# `cp /etc/dmscripts/config ${HOME}/.config/dmscripts/config`

# Defined variables, modify anything in quotes to your prefered software

# IMPORTANT! Keep the '-p' flag at the end of the DMENU and RMENU variables.
# Also, keep the '--prompt' flag at the end of the FMENU variable.
# These are needed as we use prompts in the scripts.
DMENU="dmenu -i -l 20 -p"
RMENU="rofi -theme ${XDG_CONFIG_HOME}/rofi/dmenu.rasi -dmenu -p"
# the bind must stay, why is this not the default? idk
FMENU="fzf --bind=enter:replace-query+print-query --border=rounded --margin=5% --color=dark --height 100% --reverse --header=$(basename "$0") --info=hidden --header-first --prompt"

DEFAULT_MENU=${FMENU}

PDF_VIEWER="atril"

DMBROWSER="zen-browser"

# DMTERM="st -e"
DMTERM="alacritty -e"

DMEDITOR="micro"

# TODO: Rename this variable to something more traditional
logout_locker='betterlockscreen --lock'
# logout_locker='dm-tool lock'

# dmscripts will notify you if your configuration is outdated, to shut it up uncomment this.
# comment it back out if you want dmscripts to nag at you
# DM_SHUTUP="something" # NOTICE: This is currently experimental and will not work in (most) programs

# set this variable up to a real file if you want dmscripts to provide a log of when and what has changed
# in your config (this can be an alternative to the notifications)
DM_CONFIG_DIFF_LOGFILE="/dev/stderr" # NOTICE: experimental

# This case statement lets you change what the DMENU variable is for different scripts, so if you
# want a unique variable for each script you can
# syntax is as follows:
# "<ending-of-script>") DMENU="your variable here"
# *) should be left blank, global variables are defined above

# include -p in standard dmenu as we use prompts by default
case "${0##*-}" in
#  "colpick") DMENU="dmenu -i -p";;
#  "confedit") DMENU="dmenu -i -l 30 -p";;
#  "youtube") DMBROWSER="firefox";;
*) ;;
esac

# "${0##*-}" means grab the 0th argument (which is always the path to the program) starting from the
# last dash. This gives us the word after the - which is what we are searching for in the case
# statement. ie dm-man -> man

# An awk equivalent is:
# awk -F"-" '{print $NF}'
# Sadly cut has no easy equivalent

# TODO: Move almost all of these variables into the case statement
# TODO: Make some of the more useful ones general variables
# IE a pictures directory, an audio directory, config locations, etc

# dm-sounds
sounds_dir="${HOME}/.config/dmscripts/dmsounds"

# dm-setbg
setbg_dir="/usr/share/backgrounds"
# Set this to 1 if you want to use imv and wayland, 0 if you want to use sxiv
# Note that sxiv is X11 only, you need to mark the image you want to use.
use_imv=0

# dm-maim
maim_dir="${HOME}/Screenshots"
maim_file_prefix="maim"

# dm-note
note_dir="${HOME}/.config/dmscripts/dmnote"

# We must declare all lists with the -g option

# dm-reddit config
declare -ag reddit_list=(
  "r/archlinux"
  "r/bash"
  "r/commandline"
  "r/emacs"
  "r/freesoftware"
  "r/linux"
  "r/linux4noobs"
  "r/linuxmasterrace"
  "r/linuxquestions"
  "r/suckless"
  "r/Ubuntu"
  "r/unixporn"
  "r/vim"
)

# Search engine config
declare -Ag websearch
# Syntax:
# websearch[name]="https://www.example.com/search?q="

# Search Engines
websearch[bing]="https://www.bing.com/search?q="
websearch[brave]="https://search.brave.com/search?q="
websearch[duckduckgo]="https://duckduckgo.com/?q="
websearch[google]="https://www.google.com/search?q="
websearch[qwant]="https://www.qwant.com/?q="
websearch[swisscows]="https://swisscows.com/web?query="
websearch[yandex]="https://yandex.com/search/?text="
# Information/News
websearch[bbcnews]="https://www.bbc.co.uk/search?q="
websearch[cnn]="https://www.cnn.com/search?q="
websearch[googlenews]="https://news.google.com/search?q="
websearch[wikipedia]="https://en.wikipedia.org/w/index.php?search="
websearch[wiktionary]="https://en.wiktionary.org/w/index.php?search="
# Social Media
websearch[reddit]="https://www.reddit.com/search/?q="
websearch[odysee]="https://odysee.com/$/search?q="
websearch[youtube]="https://www.youtube.com/results?search_query="
# Online Shopping
websearch[amazon]="https://www.amazon.com/s?k="
websearch[craigslist]="https://www.craigslist.org/search/sss?query="
websearch[ebay]="https://www.ebay.com/sch/i.html?&_nkw="
websearch[gumtree]="https://www.gumtree.com/search?search_category=all&q="
# Linux
websearch[archaur]="https://aur.archlinux.org/packages/?O=0&K="
websearch[archpkg]="https://archlinux.org/packages/?sort=&q="
websearch[archwiki]="https://wiki.archlinux.org/index.php?search="
websearch[debianpkg]="https://packages.debian.org/search?suite=default&section=all&arch=any&searchon=names&keywords="
# Development
websearch[github]="https://github.com/search?q="
websearch[gitlab]="https://gitlab.com/search?search="
websearch[googleOpenSource]="https://opensource.google/projects/search?q="
websearch[sourceforge]="https://sourceforge.net/directory/?q="
websearch[stackoverflow]="https://stackoverflow.com/search?q="
# Etc

# dm-color config
declare -Ag colpick_list
colpick_list[black]="${BLACK:-#14141E}"     # color0
colpick_list[red]="${RED:-#F7768E}"         # color1
colpick_list[green]="${GREEN:-#35BF88}"     # color2
colpick_list[yellow]="${YELLOW:-#DBAC66}"   # color3
colpick_list[blue]="${BLUE:-#4CA6E8}"       # color4
colpick_list[magenta]="${MAGENTA:-#BB9AF7}" # color5
colpick_list[cyan]="${CYAN:-#7DCFFF}"       # color6
colpick_list[white]="${WHITE:-#E6E6E8}"     # color7
colpick_list[orange]="${ORANGE:-#EFCA84}"   # color11 (using brighter yellow as orange)
colpick_list[purple]="${PURPLE:-#7AA2F7}"   # color12 (using brighter blue as purple)

# dm-weather config

# Example: set the default search parameters to Texas, Paris and Kyiv
# weather_locations="Texas, United States
# Paris, France
# Kyiv, Ukraine"
weather_locations="Cairo, Egypt"

# use the weather_opts variable to set additional flags:
# weather_opts="flag1&flag2&flag3=somevalue"

# for full details see: https://github.com/chubin/wttr.in

# current revision (do not touch unless you know what you're doing)
_revision=26
