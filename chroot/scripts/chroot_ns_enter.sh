#!/system/bin/sh
# chroot_ns_enter.sh -- attach a terminal to the persistent chroot namespace.
#
# No mounts are made here. It only enters the holder's mount namespace and
# chroots; all mounts already exist inside that namespace.
#
# Usage:
#   chroot_ns_enter.sh                 # interactive login shell as fire
#   chroot_ns_enter.sh -c 'nvim'       # run a command as fire
#   chroot_ns_enter.sh /bin/ls -la     # run argv as fire
#
# Called through su so it can nsenter:
#   adb shell -t 'su --no-pty -c /data/local/tmp/chroot_ns_enter.sh'
# Termux: scripts/archl-ns

CHROOT_PATH="${CHROOT_PATH:-/data/local/tmp/archl}"
UID_FIRE=1000
GID_FIRE=1000
PIDFILE="${PIDFILE:-/data/local/tmp/chroot_ns.pid}"
EPHEMERAL="${EPHEMERAL:-/data/local/tmp/chroot_ns_ephemeral.sh}"
# Extra mounts for the fallback session, so it behaves like the holder.
EPHEMERAL_OPTS="${EPHEMERAL_OPTS:---with-sdcard --with-fire}"

# Parse options first so the on-demand fallback can handle them too.
HAS_CMD=0
CMD=
while [ $# -gt 0 ]; do
    case "$1" in
        -l|--login)
            shift
            ;;
        -c|--command)
            shift
            [ $# -ge 1 ] || { echo "chroot_ns_enter: -c requires a command" >&2; exit 2; }
            CMD=$1
            HAS_CMD=1
            shift
            break
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

PID=$(cat "$PIDFILE" 2>/dev/null)
if [ -z "$PID" ] || [ ! -d "/proc/$PID" ]; then
    echo "chroot_ns_enter: no holder, falling back to on-demand namespace" >&2
    if [ -x "$EPHEMERAL" ]; then
        if [ "$HAS_CMD" = 1 ]; then
            exec /system/bin/sh "$EPHEMERAL" $EPHEMERAL_OPTS \
                /bin/sh -c 'cd "$HOME" || cd /; exec "$SHELL" -c "$1"' sh "$CMD"
        fi
        if [ $# -gt 0 ]; then
            exec /system/bin/sh "$EPHEMERAL" $EPHEMERAL_OPTS "$@"
        fi
        exec /system/bin/sh "$EPHEMERAL" $EPHEMERAL_OPTS
    fi
    echo "chroot_ns_enter: no holder and no $EPHEMERAL" >&2
    exit 1
fi

HOLDER_NS=$(readlink "/proc/$PID/ns/mnt" 2>/dev/null)
INIT_NS=$(readlink /proc/1/ns/mnt 2>/dev/null)
if [ -z "$HOLDER_NS" ] || [ "$HOLDER_NS" = "$INIT_NS" ]; then
    echo "chroot_ns_enter: holder namespace invalid (pid $PID); refusing" >&2
    exit 1
fi
if [ "$(readlink /proc/self/ns/mnt 2>/dev/null)" = "$HOLDER_NS" ]; then
    echo "chroot_ns_enter: already inside holder namespace; refusing to nest" >&2
    exit 1
fi

# Arch environment (inherited by nsenter -> chroot -> setpriv)
PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
HOME=/home/fire
USER=fire
LOGNAME=fire
TERM="${TERM:-xterm-256color}"

LOGIN_SHELL="$(awk -F: -v u="$UID_FIRE" '$3==u { print $7; exit }' "$CHROOT_PATH/etc/passwd")"
[ -x "$CHROOT_PATH$LOGIN_SHELL" ] || LOGIN_SHELL=/bin/bash
SHELL="$LOGIN_SHELL"
export PATH HOME USER LOGNAME TERM SHELL

if [ "$HAS_CMD" = 1 ]; then
    set -- /bin/sh -c 'cd "$HOME" || cd /; exec "$SHELL" -c "$1"' sh "$CMD"
elif [ $# -gt 0 ]; then
    : # argv mode: pass through as-is
else
    set -- /bin/sh -c 'cd "$HOME" || cd /; exec "$SHELL" -l'
fi

if [ -x "$CHROOT_PATH/usr/bin/setpriv" ]; then
    exec nsenter -t "$PID" -m -- \
        chroot "$CHROOT_PATH" /usr/bin/setpriv \
        --reuid="$UID_FIRE" --regid="$GID_FIRE" --init-groups "$@"
else
    exec nsenter -t "$PID" -m -- chroot "$CHROOT_PATH" "$@"
fi
