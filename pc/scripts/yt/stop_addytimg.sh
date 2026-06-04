#!/bin/bash
# Stop script for the clipboard YouTube watcher

echo "Stopping YouTube clipboard watcher..."

# Find and kill the wl-paste --watch process running addytimg.py
pkill -f "wl-paste --watch python3 .*/addytimg.py"

# Also kill any currently running instances of the python processor script
pkill -f "python3 .*/addytimg.py"

# Clean up states
rm -f /tmp/yt-watcher-active
rm -f /tmp/yt-processing
pkill -RTMIN+8 waybar

notify-send -t 2000 "YouTube Watcher" "Clipboard monitoring disabled"
echo "Clipboard watcher stopped and reddot reset."
