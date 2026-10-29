#!/system/bin/sh
# Minimal chroot launcher
# Usage: sh chroot_min.sh [cmd...]   (default: /bin/bash)

CHROOT_PATH="/data/local/tmp/archl"

# wait for boot
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done

mount -o remount,dev,suid,exec /data

mount --rbind /dev  "$CHROOT_PATH/dev"
mount --bind  /sys  "$CHROOT_PATH/sys"
mount --bind  /proc "$CHROOT_PATH/proc"
mount --bind  /data "$CHROOT_PATH/data"

mkdir -p "$CHROOT_PATH/dev/pts" "$CHROOT_PATH/tmp"
mount -t devpts devpts "$CHROOT_PATH/dev/pts"

if [ "$#" -eq 0 ]; then
    exec chroot "$CHROOT_PATH" /bin/bash
else
    exec chroot "$CHROOT_PATH" "$@"
fi