#!/usr/bin/env bash
#                         __     
#   __ _  ___ _  _____   / /____ 
#  /  ' \/ _ \ |/ / -_) / __/ _ \
# /_/_/_/\___/___/\__/  \__/\___/
#
# unhidewin.sh - Restore the most recently hidden window that belongs to the current workspace (LIFO)
# State file: ~/.cache/hypr/hidden_windows
#   Each line: <source_workspace_id>:<window_address>

STATE_DIR="$HOME/.cache/hypr"
STATE_FILE="$STATE_DIR/hidden_windows"

if [ ! -f "$STATE_FILE" ]; then
    echo "unhidewin: no hidden windows recorded"
    exit 0
fi

# Get the current active workspace id
CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')

if [ -z "$CURRENT_WS" ] || [ "$CURRENT_WS" = "null" ]; then
    echo "unhidewin: could not determine current workspace"
    exit 1
fi

# Find the last (most recently hidden) line matching the current workspace (LIFO)
MATCH_LINE=$(grep "^${CURRENT_WS}:" "$STATE_FILE" | tail -n 1)

if [ -z "$MATCH_LINE" ]; then
    echo "unhidewin: no hidden windows for workspace ${CURRENT_WS}"
    exit 0
fi

WIN_ADDR="${MATCH_LINE#*:}"

# Verify the window still exists in the special:hidden workspace
WIN_EXISTS=$(hyprctl clients -j | jq -r \
    ".[] | select(.workspace.name == \"special:hidden\" and .address == \"${WIN_ADDR}\") | .address")

if [ -z "$WIN_EXISTS" ]; then
    # Window is gone (was closed); remove the stale entry and try next
    echo "unhidewin: window ${WIN_ADDR} no longer exists, removing stale entry"
    # Remove only the last occurrence of this line
    tac "$STATE_FILE" | sed "0,/^${CURRENT_WS}:${WIN_ADDR//\//\\/}\$/{//d}" | tac > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    exec "$0"   # retry
fi

# Remove the last occurrence of this entry from the state file
tac "$STATE_FILE" | sed "0,/^${CURRENT_WS}:${WIN_ADDR//\//\\/}\$/{//d}" | tac > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

# Move the window back to the current workspace
hyprctl dispatch movetoworkspace "${CURRENT_WS},address:${WIN_ADDR}"
