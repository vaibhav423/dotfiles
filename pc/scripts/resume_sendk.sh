#!/usr/bin/env bash
PAUSE_FILE="${1:-/tmp/sendk.pause}"

rm -f "$PAUSE_FILE"
echo "sendk.py resumed"
