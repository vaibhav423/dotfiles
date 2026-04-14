#!/usr/bin/env bash
# A simple panic button script to terminate sendk.py if it is running

echo "Stopping sendk.py forcefully..."
pkill -9 -f sendk.py

if [ $? -eq 0 ]; then
    echo "sendk.py has been stopped."
else
    echo "sendk.py was not running."
fi
