#!/bin/bash

# collects all json from the dir which this file is in and shows them in rofi
# the selected entry is then edited
dir="$(dirname "$0")"
files=("$dir"/*.json)

if [ ${#files[@]} -eq 0 ] || [ ! -f "${files[0]}" ]; then
    notify-send "No .json files found in $dir"
    exit 1
fi

selected=$(printf '%s\n' "${files[@]##*/}" | rofi -dmenu -p "Edit JSON" -theme ~/.config/rofi/config-compact.rasi)

[ -z "$selected" ] && exit 1

kitty -e nvim "$dir/$selected"
