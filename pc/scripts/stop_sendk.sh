#!/usr/bin/env bash
STOP_FILE="${1:-/tmp/sendk.stop}"

touch "$STOP_FILE"
rm -f /tmp/sendk.pause
pkill -15 -f "sendk.py" 2>/dev/null

echo "Stop signal sent to sendk.py"
