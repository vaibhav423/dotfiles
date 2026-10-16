#!/system/bin/sh
# Minimal chroot launcher -> drops to user `fire`
# Usage: sh chroot_min.sh [--with-data] [cmd...]
#        --with-data  also bind /data in (mirrors the chroot inside itself; off by default)

CHROOT_PATH="/data/local/tmp/archl"
UID_FIRE=1000
GID_FIRE=1000

WITH_DATA=""
for arg in "$@"; do
    case "$arg" in
        --with-data) WITH_DATA=1 ;;
        *) break ;;
    esac
done
[ "$WITH_DATA" ] && shift

# is $CHROOT_PATH/$1 a mountpoint?
is_mounted() {
    awk -v p="$CHROOT_PATH/$1" '$2==p { f=1 } END { exit !f }' /proc/mounts
}

# bind $1 -> $CHROOT_PATH/$2, skip if already there. $3 = r for recursive.
bind() {
    is_mounted "$2" && return 0
    mkdir -p "$CHROOT_PATH/$2"
    if [ "$3" = "r" ]; then
        mount --rbind "$1" "$CHROOT_PATH/$2"
    else
        mount --bind "$1" "$CHROOT_PATH/$2"
    fi
}

# /data must allow exec or nothing inside can run
case ",$(awk '$2=="/data" { print $4; exit }' /proc/mounts)," in
    *,exec,*) ;;
    *) mount -o remount,dev,suid,exec /data ;;
esac

bind /dev  dev r   # rbind: needs submounts (dev/pts, binderfs, usb-ffs)
bind /sys  sys
bind /proc proc
[ -n "$WITH_DATA" ] && bind /data data

# CRITICAL: /dev and /data are shared-peer-group mounts on Android, so an
# --rbind clone lands in the SAME peer group. Unmounting inside the chroot then
# propagates back out and takes the HOST's mount with it (this is exactly how
# /dev/pts got torn off the host). Re-slave them so events flow in only.
# toybox mount has no propagation flags, so borrow util-linux's mount from
# inside the chroot -- propagation is a property of the mount object, so it
# applies globally no matter where you change it.
# NOTE: --make-rslave takes exactly ONE target; passing several gives
# "mount: bad usage" and silently changes nothing.
if [ -x "$CHROOT_PATH/usr/bin/mount" ]; then
    for t in /dev /sys /proc; do
        chroot "$CHROOT_PATH" /usr/bin/mount --make-rslave "$t" 2>/dev/null \
            || echo "warning: could not make $t a slave mount" >&2
    done
    if [ -n "$WITH_DATA" ]; then
        chroot "$CHROOT_PATH" /usr/bin/mount --make-rslave /data 2>/dev/null \
            || echo "warning: could not make /data a slave mount" >&2
    fi
fi

if ! is_mounted dev/pts; then
    mkdir -p "$CHROOT_PATH/dev/pts"
    mount -t devpts devpts "$CHROOT_PATH/dev/pts"
fi

# Android's PATH (/system/bin) is useless inside; set the Arch one before dropping privs
PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
HOME=/home/fire
USER=fire
LOGNAME=fire
TERM="${TERM:-xterm-256color}"

# fire's real login shell from /etc/passwd.
# Do NOT trust $SHELL -- that env var says what you *were*, not what is running.
LOGIN_SHELL="$(awk -F: -v u="$UID_FIRE" '$3==u { print $7; exit }' "$CHROOT_PATH/etc/passwd")"
[ -x "$CHROOT_PATH$LOGIN_SHELL" ] || LOGIN_SHELL=/bin/bash
SHELL="$LOGIN_SHELL"
export PATH HOME USER LOGNAME SHELL TERM

# chroot starts you in /, so cd home first; -l makes it a login shell (reads .zshrc)
if [ "$#" -eq 0 ]; then
    set -- /bin/sh -c 'cd "$HOME" || cd /; exec "$SHELL" -l'
fi

# toybox chroot has no --userspec, so drop privileges inside the chroot instead
if [ -x "$CHROOT_PATH/usr/bin/setpriv" ]; then
    exec chroot "$CHROOT_PATH" /usr/bin/setpriv \
        --reuid="$UID_FIRE" --regid="$GID_FIRE" --init-groups "$@"
else
    exec chroot "$CHROOT_PATH" "$@"
fi
