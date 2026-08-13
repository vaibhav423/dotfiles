#!/bin/bash

# run-json.sh rofi-menu.json
# shows a rofi menu from json in format
# [{"title":"" , "exec" : ""} , ... ]
# and execute the selected one using exec key
#
file="${1:-/dev/stdin}"

entries=$(jq -c 'if type == "array" then .[] else . end' "$file")

selected=$(echo "$entries" | jq -r '.title' | rofi -dmenu -p "Select" -theme ~/.config/rofi/config-compact.rasi)

[ -z "$selected" ] && exit 1

exec_cmd=$(echo "$entries" | jq -r --arg t "$selected" 'select(.title == $t) | .exec')

eval "$exec_cmd"
