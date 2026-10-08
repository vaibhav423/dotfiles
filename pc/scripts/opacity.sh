#!/usr/bin/env bash
# opacity.sh - toggle cheat window opacity via hyprctl eval window rule
STATE=/tmp/cheat_opacity_val
current=$(cat "$STATE" 2>/dev/null || echo "0.0")

if [ "$current" = "0.0" ]; then
    next="0.2"
else
    next="0.0"
fi

hyprctl eval "hl.window_rule({ match = { class = \"(cheat)\" }, opacity = \"$next override $next override\" })"
echo "$next" > "$STATE"
