#!/usr/bin/env bash
PAUSE_FILE="${1:-/tmp/sendk.pause}"

touch "$PAUSE_FILE"
echo "sendk.py paused"
