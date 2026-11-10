#!/system/bin/sh
# chroot_ns_ephemeral.sh -- one-shot chroot in a PRIVATE mount namespace.
#
# Use when no persistent holder is running (or for a disposable session).
# Mounts are only visible to this process tree and are discarded by the kernel
# when the last process exits. No cleanup script needed.
#
# Usage:
#   chroot_ns_ephemeral.sh                     # login shell as fire
#   chroot_ns_ephemeral.sh -c 'uname -a'       # command as fire (via shell)
#   chroot_ns_ephemeral.sh /bin/ls -la         # argv as fire
#   chroot_ns_ephemeral.sh --with-data         # also plain-bind /data
#   chroot_ns_ephemeral.sh --with-sdcard       # bind /sdcard
#   chroot_ns_ephemeral.sh --with-fire         # bind Documents/Fire
#   chroot_ns_ephemeral.sh --with-termux-tmp   # bind Termux tmp + X11 socket
#
# Options are parsed only before the command.

CHROOT_PATH="${CHROOT_PATH:-/data/local/tmp/archl}"
UID_FIRE=1000
GID_FIRE=1000
TERMUX_PREFIX="${TERMUX_PREFIX:-/data/data/com.termux/files}"
LD="$CHROOT_PATH/usr/lib/ld-linux-aarch64.so.1"
ULIB="$CHROOT_PATH/usr/lib"

if [ -z "$_CHROOT_NS_EPHEMERAL_INNER" ]; then
    if [ ! -x "$LD" ]; then
        echo "chroot_ns_ephemeral: missing $LD" >&2
        exit 1
    fi
    _CHROOT_NS_EPHEMERAL_INNER=1
    export _CHROOT_NS_EPHEMERAL_INNER
    exec "$LD" --library-path "$ULIB" "$CHROOT_PATH/usr/bin/unshare" \
        --propagation private --mount \
        /system/bin/sh "$0" "$@"
fi

WITH_DATA=""
WITH_SDCARD=""
WITH_FIRE=""
WITH_TERMUX_TMP=""
while [ $# -gt 0 ]; do
    case "$1" in
        --with-data)       WITH_DATA=1; shift ;;
        --with-sdcard)     WITH_SDCARD=1; shift ;;
        --with-fire)       WITH_FIRE=1; shift ;;
        --with-termux-tmp) WITH_TERMUX_TMP=1; shift ;;
        -c|--command)
            shift
            [ $# -ge 1 ] || { echo "chroot_ns_ephemeral: -c requires a command" >&2; exit 2; }
            CMD=$1
            shift
            set -- /bin/sh -c "$CMD"
            break
            ;;
        --) shift; break ;;
        *) break ;;
    esac
done

mounted() {
    awk -v p="$1" '$5==p { f=1 } END { exit !f }' /proc/self/mountinfo
}

bind_one() {
    _src="$1"; _dst="$2"; _rec="$3"
    [ -d "$_dst" ] || mkdir -p "$_dst"
    mounted "$_dst" && return 0
    if [ "$_rec" = "r" ]; then
        mount --rbind "$_src" "$_dst"
    else
        mount --bind "$_src" "$_dst"
    fi
}

case ",$(awk '$5=="/data" { print $6; exit }' /proc/self/mountinfo)," in
    *,exec,*) ;;
    *) mount -o remount,dev,suid,exec /data 2>/dev/null ;;
esac

bind_one /dev  "$CHROOT_PATH/dev"  r
bind_one /sys  "$CHROOT_PATH/sys"  r
bind_one /proc "$CHROOT_PATH/proc"

[ -n "$WITH_DATA" ] && bind_one /data "$CHROOT_PATH/data"
if [ -n "$WITH_SDCARD" ] && [ -d /sdcard ]; then
    bind_one /sdcard "$CHROOT_PATH/sdcard"
fi
if [ -n "$WITH_FIRE" ] && [ -d /data/media/0/Documents/Fire ]; then
    bind_one /data/media/0/Documents/Fire "$CHROOT_PATH/home/fire/Water/Fire"
fi
if [ -n "$WITH_TERMUX_TMP" ] && [ -d "$TERMUX_PREFIX/usr/tmp" ]; then
    bind_one "$TERMUX_PREFIX/usr/tmp" "$CHROOT_PATH/termux-tmp"
    [ -d "$TERMUX_PREFIX/usr/tmp/.X11-unix" ] && \
        bind_one "$TERMUX_PREFIX/usr/tmp/.X11-unix" "$CHROOT_PATH/tmp/.X11-unix"
fi

PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
HOME=/home/fire
USER=fire
LOGNAME=fire
TERM="${TERM:-xterm-256color}"

LOGIN_SHELL="$(awk -F: -v u="$UID_FIRE" '$3==u { print $7; exit }' "$CHROOT_PATH/etc/passwd")"
[ -x "$CHROOT_PATH$LOGIN_SHELL" ] || LOGIN_SHELL=/bin/bash
SHELL="$LOGIN_SHELL"
export PATH HOME USER LOGNAME TERM SHELL

if [ "$#" -eq 0 ]; then
    set -- /bin/sh -c 'cd "$HOME" || cd /; exec "$SHELL" -l'
fi

if [ -x "$CHROOT_PATH/usr/bin/setpriv" ]; then
    exec chroot "$CHROOT_PATH" /usr/bin/setpriv \
        --reuid="$UID_FIRE" --regid="$GID_FIRE" --init-groups "$@"
else
    exec chroot "$CHROOT_PATH" "$@"
fi
