#!/bin/bash
DATE=$(date +%Y-%m-%d)
FILE="$HOME/Water/Fire/journal/$DATE.md"
if [ ! -f "$FILE" ]; then
    echo "[[scratch]]" >> "$FILE"
fi
nvim "$FILE"
