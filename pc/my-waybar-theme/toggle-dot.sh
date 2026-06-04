#!/bin/bash
STATE_FILE="/tmp/waybar-red-dot-state"

if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
else
    touch "$STATE_FILE"
fi

pkill -RTMIN+8 waybar
