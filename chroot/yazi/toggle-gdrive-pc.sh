#!/usr/bin/env bash
set -euo pipefail

MOUNT="$HOME/gdriveix"

if mountpoint -q "$MOUNT"; then
	fusermount -uz "$MOUNT"
	echo "Google Drive unmounted"
else
	mkdir -p "$MOUNT"
	rclone mount ix: "$MOUNT" \
		--vfs-cache-mode full \
		--vfs-cache-max-size 10G \
		--vfs-read-chunk-size 64M \
		--buffer-size 64M &
	echo "Google Drive mounted"
fi
