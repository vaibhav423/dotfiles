#!/system/bin/sh
# chroot_ns_holder.sh -- runs INSIDE the persistent slave mount namespace.
#
# Started by chroot_ns_boot.sh (or manually) via util-linux:
#   unshare --propagation slave --mount /system/bin/sh chroot_ns_holder.sh
#
# Every mount made here belongs to this namespace only. init, zygote, apps and
# Duck Detector read their own namespaces and never see these mounts.
#
# Why slave and not private:
#   /sdcard and vold's FUSE mounts appear AFTER boot/unlock. A slave namespace
#   receives mount events from the global namespace, so the chroot sees them
#   later. Mounts created here never propagate back out.

CHROOT_PATH="${CHROOT_PATH:-/data/local/tmp/archl}"
UID_FIRE=1000
GID_FIRE=1000
TERMUX_PREFIX="${TERMUX_PREFIX:-/data/data/com.termux/files}"
PIDFILE="${PIDFILE:-/data/local/tmp/chroot_ns.pid}"

WITH_BINDFS="${CHROOT_WITH_BINDFS:-1}"
WITH_SSHD="${CHROOT_WITH_SSHD:-0}"

ARCH_LINKER="$CHROOT_PATH/usr/lib/ld-linux-aarch64.so.1"
LIB_PATH="$CHROOT_PATH/usr/lib"

log() { echo "$(date '+%H:%M:%S') $*"; }

mounted() {
    # $1 = mount point in this namespace
    awk -v p="$1" '$5==p { f=1 } END { exit !f }' /proc/self/mountinfo
}

bind_one() {
    _src="$1"; _dst="$2"; _rec="$3"
    [ -d "$_dst" ] || mkdir -p "$_dst"
    mounted "$_dst" && return 0
    if [ "$_rec" = "r" ]; then
        mount --rbind "$_src" "$_dst" || log "WARN: rbind $_src -> $_dst failed"
    else
        mount --bind "$_src" "$_dst" || log "WARN: bind $_src -> $_dst failed"
    fi
}

# /data must allow exec inside this namespace. exec/dev/suid are per-mount
# flags, so the global /data mount is not changed.
case ",$(awk '$5=="/data" { print $6; exit }' /proc/self/mountinfo)," in
    *,exec,*) ;;
    *) mount -o remount,dev,suid,exec /data 2>/dev/null || log "WARN: remount /data failed" ;;
esac

# Core mounts.
# NOTE: no fresh devpts. rbind /dev shares the host devpts so a direct
# adb/Termux login keeps a valid /dev/pts/N (tty, job control, /dev/tty).
bind_one /dev  "$CHROOT_PATH/dev"  r
bind_one /sys  "$CHROOT_PATH/sys"  r
bind_one /proc "$CHROOT_PATH/proc"

# Android partitions some binaries need.
bind_one /system      "$CHROOT_PATH/system"
bind_one /apex        "$CHROOT_PATH/apex" r
bind_one /linkerconfig "$CHROOT_PATH/linkerconfig"

for p in vendor product odm system_ext; do
    [ -d "/$p" ] && bind_one "/$p" "$CHROOT_PATH/$p" r
done

mkdir -p "$CHROOT_PATH/dev/shm" "$CHROOT_PATH/tmp" "$CHROOT_PATH/sdcard" \
         "$CHROOT_PATH/termux-tmp" "$CHROOT_PATH/tmp/.X11-unix" \
         "$CHROOT_PATH/home/fire/Water/Fire" "$CHROOT_PATH/run/sshd"

mounted "$CHROOT_PATH/dev/shm" || \
    mount -t tmpfs -o size=256M tmpfs "$CHROOT_PATH/dev/shm" 2>/dev/null || \
    log "WARN: /dev/shm tmpfs failed"

# bindfs /data: ownership-mapped view for fire. FUSE mount, stays in this ns.
if [ "$WITH_BINDFS" = "1" ] && [ -x "$CHROOT_PATH/usr/bin/bindfs" ] && [ -x "$ARCH_LINKER" ]; then
    mkdir -p "$CHROOT_PATH/data"
    if ! mounted "$CHROOT_PATH/data"; then
        "$ARCH_LINKER" --library-path "$LIB_PATH" "$CHROOT_PATH/usr/bin/bindfs" \
            -o suid -u "$UID_FIRE" -g "$GID_FIRE" /data "$CHROOT_PATH/data" \
            && log "bindfs /data mounted" || log "WARN: bindfs /data failed"
    fi
fi

# Optional sshd, inside the same namespace. Default off for direct/adb use.
# Set CHROOT_WITH_SSHD=1 here (or in the environment) to enable.
if [ "$WITH_SSHD" = "1" ] && [ -x "$CHROOT_PATH/usr/bin/sshd" ]; then
    if [ -f "$CHROOT_PATH/run/sshd.pid" ] && \
       kill -0 "$(cat "$CHROOT_PATH/run/sshd.pid")" 2>/dev/null; then
        log "sshd already running"
    else
        chroot "$CHROOT_PATH" /usr/bin/sshd && log "sshd started" || log "WARN: sshd failed"
    fi
fi

HOLDER_PID=$$
echo "$HOLDER_PID" > "$PIDFILE"

# CE watcher. vold mounts /sdcard only after unlock; this namespace is a
# slave, so the global FUSE mounts appear here automatically. We only bind
# the final paths into the chroot, still inside this namespace.
(
    log "waiting for CE storage (holder $HOLDER_PID)"
    while [ "$(getprop sys.user.0.ce_available)" != "true" ]; do
        [ -d "/proc/$HOLDER_PID" ] || exit 0
        sleep 3
    done
    sleep 3
    [ -d "/proc/$HOLDER_PID" ] || exit 0

    mkdir -p "$CHROOT_PATH/sdcard" "$CHROOT_PATH/termux-tmp" \
             "$CHROOT_PATH/tmp/.X11-unix" "$CHROOT_PATH/home/fire/Water/Fire"

    if [ -d /sdcard ] && ! mounted "$CHROOT_PATH/sdcard"; then
        mount --bind /sdcard "$CHROOT_PATH/sdcard" \
            && log "bound /sdcard" || log "WARN: /sdcard bind failed"
    fi
    if [ -d /data/media/0/Documents/Fire ] && \
       ! mounted "$CHROOT_PATH/home/fire/Water/Fire"; then
        mount --bind /data/media/0/Documents/Fire "$CHROOT_PATH/home/fire/Water/Fire" \
            && log "bound Water/Fire" || log "WARN: Water/Fire bind failed"
    fi
    if [ -d "$TERMUX_PREFIX/usr/tmp" ] && ! mounted "$CHROOT_PATH/termux-tmp"; then
        mount --bind "$TERMUX_PREFIX/usr/tmp" "$CHROOT_PATH/termux-tmp" \
            && log "bound termux-tmp" || log "WARN: termux-tmp bind failed"
    fi
    if [ -d "$TERMUX_PREFIX/usr/tmp/.X11-unix" ] && \
       ! mounted "$CHROOT_PATH/tmp/.X11-unix"; then
        mount --bind "$TERMUX_PREFIX/usr/tmp/.X11-unix" "$CHROOT_PATH/tmp/.X11-unix" \
            && log "bound X11" || log "WARN: X11 bind failed"
    fi
    log "CE mounts done"
) &
echo "$!" > "${PIDFILE}.ce" 2>/dev/null

log "holder ready (pid $HOLDER_PID, ns $(readlink /proc/self/ns/mnt))"

# Keep the namespace alive. exec keeps the same PID; stop helper kills the
# whole namespace (including this sleep) by ns inode.
exec sleep 2147483647
