#!/usr/bin/env bash
#                         __     
#   __ _  ___ _  _____   / /____ 
#  /  ' \/ _ \ |/ / -_) / __/ _ \
# /_/_/_/\___/___/\__/  \__/\___/
#
# hidewin.sh - Move the active window to special:hidden workspace
# State is stored in ~/.cache/hypr/hidden_windows as lines of:
#   <source_workspace_id>:<window_address>
STATE_DIR="$HOME/.cache/hypr"
STATE_FILE="$STATE_DIR/hidden_windows"
mkdir -p "$STATE_DIR"
# Get active window info
ACTIVE=$(hyprctl activewindow -j)
if [ -z "$ACTIVE" ] || [ "$ACTIVE" = "null" ]; then
    echo "hidewin: no active window found"
    exit 1
fi
WIN_ADDR=$(echo "$ACTIVE" | jq -r '.address')
SRC_WS=$(echo "$ACTIVE"   | jq -r '.workspace.id')
if [ -z "$WIN_ADDR" ] || [ "$WIN_ADDR" = "null" ]; then
    echo "hidewin: could not determine window address"
    exit 1
fi
if [ -z "$SRC_WS" ] || [ "$SRC_WS" = "null" ]; then
    echo "hidewin: could not determine source workspace"
    exit 1
fi
# Record the mapping before moving
echo "${SRC_WS}:${WIN_ADDR}" >> "$STATE_FILE"
# Move the window to the special hidden workspace (silent = don't switch to it)
hyprctl dispatch movetoworkspacesilent "special:hidden,address:${WIN_ADDR}"
