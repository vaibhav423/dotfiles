#!/usr/bin/env bash
set -euo pipefail

MOUNT="$HOME/gdriveix"

if mountpoint -q "$MOUNT"; then
	sudo fusermount3 -uz "$MOUNT"
	echo "Google Drive unmounted"
else
	mkdir -p "$MOUNT"
	# /dev/fuse is root-only in Android's chroot environment (no fuse group,
	# no setuid fusermount). Run rclone as root via sudo; --uid/--gid make
	# all files appear owned by fire so yazi/nvim work without permission issues.
	sudo rclone mount ix: "$MOUNT" \
		--config "$HOME/.config/rclone/rclone.conf" \
		--vfs-cache-mode full \
		--vfs-cache-max-size 10G \
		--vfs-read-chunk-size 64M \
		--buffer-size 64M \
		--uid "$(id -u)" \
		--gid "$(id -g)" \
		--allow-other \
		--daemon
	echo "Google Drive mounted at $MOUNT"
fi
