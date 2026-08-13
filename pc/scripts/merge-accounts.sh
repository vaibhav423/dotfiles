#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <dest-file> <src-file>" >&2
  echo "Merges accounts from src-file into dest-file, keeping dest-file entries on email conflict." >&2
  exit 1
fi

DEST="$1"
SRC="$2"

if [ ! -f "$DEST" ]; then
  echo "Error: dest file does not exist: $DEST" >&2
  exit 1
fi

if [ ! -f "$SRC" ]; then
  echo "Error: src file does not exist: $SRC" >&2
  exit 1
fi

jq -s '
  .[1] as $src |
  .[0] as $dst |
  ($dst.accounts | map(.email)) as $existing |
  ($src.accounts | map(select(.email | IN($existing[]) | not))) as $new |
  $dst | .accounts = (.accounts + $new)
' "$DEST" "$SRC" > "${DEST}.tmp"

mv "${DEST}.tmp" "$DEST"

echo "Merged $(jq -r '.accounts[] | .email' "$SRC" | wc -l | tr -d ' ') source accounts: $(jq -r '[.accounts[].email] | length' "$DEST") total in $DEST"