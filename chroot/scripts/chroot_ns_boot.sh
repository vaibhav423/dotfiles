#!/system/bin/sh
# chroot_ns_boot.sh -- boot entry for the persistent chroot namespace.
#
# Deploy as a NEW file, e.g. /data/adb/service.d/chroot_ns.sh.
# Do not keep the old chroot_sshd.sh running at the same time: it mounts in
# the global namespace and is what leaks /data/local/tmp/archl/... to apps.
#
# Flow:
#   wait for boot -> global setup (WoWLAN, sepolicy, IPv6) ->
#   enter init's mount namespace -> unshare --propagation slave ->
#   chroot_ns_holder.sh (mounts, optional sshd, pid file, sleep)

CHROOT_PATH="${CHROOT_PATH:-/data/local/tmp/archl}"
HOLDER="${HOLDER:-/data/local/tmp/chroot_ns_holder.sh}"
PIDFILE="${PIDFILE:-/data/local/tmp/chroot_ns.pid}"
LOG="${LOG:-/data/local/tmp/chroot_ns_boot.log}"

LD="$CHROOT_PATH/usr/lib/ld-linux-aarch64.so.1"
ULIB="$CHROOT_PATH/usr/lib"
UNSHARE="$CHROOT_PATH/usr/bin/unshare"

exec >"$LOG" 2>&1
echo "=== chroot_ns boot $(date) ==="

# 1. Wait for boot
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3
done
echo "boot completed at $(date)"

# 2. Global (non-mount) setup, same behaviour as the old boot script
if command -v iw >/dev/null 2>&1; then
    iw phy phy0 wowlan enable magic-packet \
        && echo "WoWLAN magic-packet enabled" \
        || echo "WARNING: WoWLAN setup failed"
fi

for mp in /data/adb/ap/bin/magiskpolicy /data/adb/magisk/magiskpolicy; do
    if [ -x "$mp" ]; then
        "$mp" --live \
            'allow untrusted_app_all magisk unix_stream_socket { connectto read write getattr }' \
            && echo "sepolicy applied via $mp" \
            || echo "WARNING: sepolicy apply failed"
        break
    fi
done

# EUI-64 IPv6 on Wi-Fi/hotspot interfaces (global sysctl, not a mount)
(
    while :; do
        for iface in wlan0 wlan1 wlan2 softap0; do
            f="/proc/sys/net/ipv6/conf/$iface/addr_gen_mode"
            [ -f "$f" ] || continue
            if [ "$(cat "$f")" != "0" ]; then
                echo 0 > "$f" 2>/dev/null
                echo 0 > "/proc/sys/net/ipv6/conf/$iface/use_tempaddr" 2>/dev/null
            fi
        done
        sleep 5
    done
) &

# 3. Launch the holder in a fresh slave namespace
rm -f "$PIDFILE" "${PIDFILE}.ce"

if [ ! -x "$LD" ]; then
    echo "ERROR: missing $LD (CHROOT_PATH wrong?)"
    exit 1
fi
if [ ! -x "$UNSHARE" ]; then
    echo "ERROR: missing $UNSHARE (util-linux inside chroot?)"
    exit 1
fi

# Start from init's mount namespace; service.d context may differ.
NS=""
if nsenter -t 1 -m -- true 2>/dev/null; then
    NS="nsenter -t 1 -m --"
else
    echo "WARNING: cannot nsenter init mount ns; using current namespace"
fi

if command -v setsid >/dev/null 2>&1; then
    setsid $NS "$LD" --library-path "$ULIB" "$UNSHARE" \
        --propagation slave --mount \
        /system/bin/sh "$HOLDER" &
else
    $NS "$LD" --library-path "$ULIB" "$UNSHARE" \
        --propagation slave --mount \
        /system/bin/sh "$HOLDER" &
fi

# 4. Wait for the holder to finish mounting
i=0
while [ ! -s "$PIDFILE" ] && [ "$i" -lt 20 ]; do
    sleep 1
    i=$((i + 1))
done

if [ -s "$PIDFILE" ]; then
    echo "holder pid $(cat "$PIDFILE")"
else
    echo "WARNING: holder pid file not created; check $LOG"
fi

echo "=== chroot_ns boot finished at $(date) ==="
