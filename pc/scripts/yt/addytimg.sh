#!/bin/bash
# Wrapper script to watch the clipboard for yt links and process them

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

echo "Starting clipboard watcher for YouTube links..."
touch /tmp/yt-watcher-active
pkill -RTMIN+8 waybar
notify-send -t 2000 "YouTube Watcher" "Clipboard monitoring enabled"

wl-paste --watch python3 "$SCRIPT_DIR/addytimg.py"
