#!/bin/bash
# Toggle script for the clipboard YouTube watcher

# Check if the watcher is currently running
if pgrep -f "wl-paste --watch python3 .*/addytimg.py" > /dev/null; then
    echo "Watcher is running. Stopping it..."
    /home/ixdire/Water/crap/scripts/stop_addytimg.sh
else
    echo "Watcher is NOT running. Starting it..."
    /home/ixdire/Water/crap/scripts/addytimg.sh &
fi
