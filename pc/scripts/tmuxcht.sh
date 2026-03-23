#!/usr/bin/env bash
selected=$(cat ~/Water/scripts/tmux-cht-lan ~/Water/scripts/tmux-cht-cmd | fzf)
if [[ -z $selected ]]; then
    exit 0
fi

read -p "Enter Query: " query

if grep -qs "$selected" ~/Water/scripts/tmux-cht-lan; then
    query=$(echo $query | tr ' ' '+')
    tmux neww bash -c "curl -s cht.sh/$selected/$query | less"
else
    tmux neww bash -c "curl -s cht.sh/$selected~$query | less"
fi
