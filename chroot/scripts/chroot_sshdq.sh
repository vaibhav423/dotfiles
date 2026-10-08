# Chroot SSHD boot script for APatch - Fast Boot & FBE Aware
# Location: /data/adb/service.d/chroot_sshd.sh

# Configuration
CHROOT_PATH="/data/local/tmp/archl"
TERMUX_PREFIX="/data/data/com.termux/files"
LIB_PATH="$CHROOT_PATH/usr/lib"
BINDFS="$CHROOT_PATH/usr/bin/bindfs"
SSHD_BIN="/usr/bin/sshd"
UID_FIRE=1000
GID_FIRE=1000
ARCH_LINKER="$CHROOT_PATH/usr/lib/ld-linux-aarch64.so.1"

# Log output for debugging
exec > /data/local/tmp/chroot_sshd_boot.log 2>&1
echo "Starting Chroot SSHD boot script at $(date)"

# 1. Wait for official Android boot completion
echo "Waiting for sys.boot_completed..."
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3
done
echo "System boot completed at $(date)."

# Enable WoWLAN magic-packet so phone wakes from Doze when laptop sends a WoL packet before SSH.
# Pattern match is broken on this driver (max offset=0), "any" is too noisy.
# Magic-packet is zero battery cost at idle — firmware wakes CPU only on WoL frame.
iw phy phy0 wowlan enable magic-packet && echo "WoWLAN magic-packet enabled." || echo "WARNING: WoWLAN setup failed."

# Apply SELinux policies early so the environment is fully prepped
# magisk unix_stream_socket: required for Termux:API (clipboard etc) from chroot.
# Note: Water/Fire now lives natively in /data/media/0/Documents/Fire which has
# media_rw_data_file context — no shell_data_file grants needed for Fire access.
echo "Applying SELinux policies..."
su -c "/data/adb/ap/bin/magiskpolicy --live \
  'allow untrusted_app_all magisk unix_stream_socket { connectto read write getattr }'" || true

# 2. IMMEDIATE CORE MOUNTS
if ! grep -q "$CHROOT_PATH/proc" /proc/mounts; then
    echo "Setting up core mounts for $CHROOT_PATH..."
    mount -o remount,dev,suid,exec /data

    # Core system mounts
    mount --rbind /dev "$CHROOT_PATH/dev"
    mount --bind /sys "$CHROOT_PATH/sys"
    mount --bind /proc "$CHROOT_PATH/proc"
    mount --bind /system "$CHROOT_PATH/system"
    mount --rbind /apex "$CHROOT_PATH/apex"
    mount --bind /linkerconfig "$CHROOT_PATH/linkerconfig"

    # Android Partitions
    [ -d /vendor ] && { mkdir -p "$CHROOT_PATH/vendor"; mount --bind /vendor "$CHROOT_PATH/vendor"; }
    [ -d /product ] && { mkdir -p "$CHROOT_PATH/product"; mount --bind /product "$CHROOT_PATH/product"; }
    [ -d /odm ] && { mkdir -p "$CHROOT_PATH/odm"; mount --bind /odm "$CHROOT_PATH/odm"; }
    [ -d /system_ext ] && { mkdir -p "$CHROOT_PATH/system_ext"; mount --bind /system_ext "$CHROOT_PATH/system_ext"; }

    # Create necessary directories (persistent mountpoints, not data/adb — that's covered by bindfs)
    mkdir -p "$CHROOT_PATH/termux-tmp" "$CHROOT_PATH/tmp" "$CHROOT_PATH/sdcard" "$CHROOT_PATH/dev/shm"

    # Pseudo-terminals and shared memory
    mount -t devpts devpts "$CHROOT_PATH/dev/pts"
    mount -t tmpfs -o size=256M tmpfs "$CHROOT_PATH/dev/shm"

    # Mount /data immediately via bindfs - /data is DE storage, available before user unlock.
    # bindfs remaps all ownership to fire:fire (uid/gid 1000) so fire can browse
    # /data without sudo. Uses chroot's own linker+bindfs, no Termux dependency.
    echo "Mounting /data via bindfs..."
    "$ARCH_LINKER" --library-path "$LIB_PATH" "$BINDFS" \
        -o suid -u $UID_FIRE -g $GID_FIRE /data "$CHROOT_PATH/data" \
        && echo "bindfs /data mounted at $(date)." \
        || echo "WARNING: bindfs /data failed at $(date)."

    echo "Core mounts completed at $(date)."
else
    echo "Core mounts already active."
fi

# 3. START SSHD IMMEDIATELY
# /var/run is a symlink to ../run in Arch, so /run/sshd.pid is the real pid file.
echo "Preparing SSHD..."
mkdir -p "$CHROOT_PATH/run/sshd"

SSHD_PID_FILE="$CHROOT_PATH/run/sshd.pid"
if [ -f "$SSHD_PID_FILE" ] && kill -0 "$(cat "$SSHD_PID_FILE")" 2>/dev/null; then
    echo "sshd is already running."
else
    echo "Starting sshd inside chroot..."
    chroot "$CHROOT_PATH" "$SSHD_BIN"
    echo "sshd started at $(date)."
fi

# 4. BACKGROUND: WAIT FOR CE STORAGE UNLOCK (sdcard + X11 bridge)
# /sdcard is a FUSE mount set up by vold only after the user unlocks the screen.
# sys.user.0.ce_available=true is the authoritative vold signal for CE key load.
# No timeout - there is no harm in waiting indefinitely for a user unlock.
(
    echo "Waiting for CE storage unlock (sys.user.0.ce_available)..."
    while [ "$(getprop sys.user.0.ce_available)" != "true" ]; do
        sleep 3
    done
    echo "CE storage unlocked at $(date). Settling for 3 seconds..."
    sleep 3

    echo "Setting up sdcard & X11 bridge mounts..."

    # X11 socket bridge (Termux:X11 -> chroot /tmp)
    # termux/usr/tmp is already 777 (Termux sets it). mkdir only, no chmod needed.
    mkdir -p "$TERMUX_PREFIX/usr/tmp/.X11-unix" "$CHROOT_PATH/tmp/.X11-unix"
    mount --bind "$TERMUX_PREFIX/usr/tmp" "$CHROOT_PATH/termux-tmp"
    mount --bind "$TERMUX_PREFIX/usr/tmp/.X11-unix" "$CHROOT_PATH/tmp/.X11-unix"

    # sdcard via global mount namespace (su -mm) so vold's FUSE mounts are visible.
    su -mm -c "mount --bind /sdcard $CHROOT_PATH/sdcard"

    # Water/Fire now lives natively at /data/media/0/Documents/Fire (media_rw_data_file).
    # Bind it into the chroot so the chroot path /home/fire/Water/Fire works as before.
    # Direction: /data/media/0/Documents/Fire -> $CHROOT_PATH/home/fire/Water/Fire
    # This is a cross-context bind (media lower fs -> chroot mountpoint), no FUSE cycle.
    # Must run from init/global namespace (su -mm) — see mounts.md for full explanation.
    su -mm -c "mount --bind /data/media/0/Documents/Fire $CHROOT_PATH/home/fire/Water/Fire"

    echo "CE storage mounts completed successfully at $(date)."
) &

# Force EUI-64 IPv6 addresses on all Wi-Fi and Hotspot interfaces (bypasses Android RFC7217 privacy)
(
    while true; do
        for iface in wlan0 wlan1 wlan2 softap0; do
            if [ -f "/proc/sys/net/ipv6/conf/$iface/addr_gen_mode" ]; then
                # 0 = EUI-64, 2 = Stable Privacy (Android default)
                if [ "$(cat "/proc/sys/net/ipv6/conf/$iface/addr_gen_mode")" != "0" ]; then
                    echo 0 > "/proc/sys/net/ipv6/conf/$iface/addr_gen_mode" 2>/dev/null
                    echo 0 > "/proc/sys/net/ipv6/conf/$iface/use_tempaddr" 2>/dev/null
                fi
            fi
        done
        sleep 5
    done
) &

echo "-----------------------------------------------------------------------------------------------"
echo "Main boot script finished successfully at $(date). CE storage mounts running in background."
echo "-----------------------------------------------------------------------------------------------"
