#!/system/bin/sh
# chroot_ns_stop.sh -- stop the persistent chroot namespace cleanly.
#
# Kills every process whose mount namespace inode matches the holder, so
# sshd, bindfs, tmux, shells and the holder itself all go away and the kernel
# destroys the namespace (and every mount in it) automatically.

CHROOT_PATH="${CHROOT_PATH:-/data/local/tmp/archl}"
PIDFILE="${PIDFILE:-/data/local/tmp/chroot_ns.pid}"

PID=$(cat "$PIDFILE" 2>/dev/null)
if [ -z "$PID" ] || [ ! -d "/proc/$PID" ]; then
    echo "chroot_ns_stop: not running"
    rm -f "$PIDFILE" "${PIDFILE}.ce"
    exit 0
fi

HOLDER_NS=$(readlink "/proc/$PID/ns/mnt" 2>/dev/null)
INIT_NS=$(readlink /proc/1/ns/mnt 2>/dev/null)
SELF_NS=$(readlink /proc/self/ns/mnt 2>/dev/null)

if [ -z "$HOLDER_NS" ] || [ "$HOLDER_NS" = "$INIT_NS" ]; then
    echo "chroot_ns_stop: refusing: pid $PID is not in a private/slave namespace" >&2
    exit 1
fi
if [ "$SELF_NS" = "$HOLDER_NS" ]; then
    echo "chroot_ns_stop: run this from outside the chroot" >&2
    exit 1
fi

echo "stopping namespace $HOLDER_NS (holder $PID)"
for p in /proc/[0-9]*; do
    pns=$(readlink "$p/ns/mnt" 2>/dev/null) || continue
    [ "$pns" = "$HOLDER_NS" ] || continue
    kill "${p#/proc/}" 2>/dev/null
done

sleep 1

# Force anything that ignored SIGTERM (the holder is normally `sleep`).
for p in /proc/[0-9]*; do
    pns=$(readlink "$p/ns/mnt" 2>/dev/null) || continue
    [ "$pns" = "$HOLDER_NS" ] || continue
    kill -9 "${p#/proc/}" 2>/dev/null
done

rm -f "$PIDFILE" "${PIDFILE}.ce"
echo "stopped"
