#!/system/bin/sh
# Chroot SSHD boot script for Magisk - Stability & Sync Enhanced
# Location: /data/adb/service.d/chroot_sshd.sh

# Configuration
CHROOT_PATH="/data/local/tmp/archl"
TERMUX_PREFIX="/data/data/com.termux/files"
SSHD_BIN="/usr/bin/sshd"
UID_FIRE=1000
GID_FIRE=1000

# Log output for debugging
exec > /data/local/tmp/chroot_sshd_boot.log 2>&1
echo "Starting Chroot SSHD boot script at $(date)"

# 1. Wait for official Android boot completion
echo "Waiting for sys.boot_completed..."
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3
done
echo "System boot completed."

# 2. Wait for /sdcard to be fully mounted by the system host
echo "Waiting for /storage/emulated/0 to appear in /proc/mounts..."
max_wait=30
while ! grep -q "/storage/emulated/0" /proc/mounts && [ $max_wait -gt 0 ]; do
    sleep 2
    max_wait=$((max_wait - 1))
done

# 3. Final settle delay for Media Provider and storage layers
echo "Settling for 5 seconds..."
sleep 5

# 4. Turn on global mount propagation for the data block
# This allows namespaces to share mount mappings seamlessly
mount --make-rshared /data

# 5. Initialize Chroot Environment & Bridges
if ! grep -q "$CHROOT_PATH/proc" /proc/mounts; then
    echo "Setting up mounts for $CHROOT_PATH..."
    mount -o remount,dev,suid,exec /data
    
    # Core Linux Environment Mounts
    mount --rbind /dev "$CHROOT_PATH/dev"
    mount --bind /sys "$CHROOT_PATH/sys"
    mount --bind /proc "$CHROOT_PATH/proc"
    mount --bind /system "$CHROOT_PATH/system"
    mount --rbind /apex "$CHROOT_PATH/apex"
    mount --bind /linkerconfig "$CHROOT_PATH/linkerconfig"
    
    # Required structure setup
    mkdir -p "$CHROOT_PATH/termux-tmp" "$CHROOT_PATH/tmp" "$CHROOT_PATH/termux" "$CHROOT_PATH/sdcard" "$CHROOT_PATH/dev/shm" "$CHROOT_PATH/data"
    mount -t devpts devpts "$CHROOT_PATH/dev/pts"
    mount -t tmpfs -o size=256M tmpfs "$CHROOT_PATH/dev/shm"
    
    # Pass Termux temporary folders natively
    chmod -R 777 "$TERMUX_PREFIX/usr/tmp"
    mount --bind "$TERMUX_PREFIX/usr/tmp" "$CHROOT_PATH/tmp"

    # --- THE SYNC BRIDGE ARCHITECTURE ---
    
    # A. Establish the Physical Bridge FIRST
    # Map your Chroot home workspace directory straight into the Android backing store
    mkdir -p /data/media/0/Documents/Fire
    mount --bind "$CHROOT_PATH/home/fire/Water/Fire" /data/media/0/Documents/Fire
    mount --make-rshared /data/media/0/Documents/Fire

    # B. Bring the Android Shared Storage into Chroot recursively
    # --rbind is critical here: it brings the 'Fire' sub-mount along for the ride inside /sdcard
    mount --rbind /data/media/0 "$CHROOT_PATH/sdcard"
    mount --make-rshared "$CHROOT_PATH/sdcard"

    # C. Raw bind for the /data partition (replacing the old slow bindfs)
    mount --bind /data "$CHROOT_PATH/data"
    
    echo "Mounts completed successfully."
else
    echo "Mounts already active."
fi

# 6. Final Permission & Ownership Alignment
# Since 'fire' is UID 1000, we match it to the Android system user/media groups
chown -R 1000:1023 "$CHROOT_PATH/home/fire/Water/Fire"
chmod -R 2775 "$CHROOT_PATH/home/fire/Water/Fire"

# 7. Secure Shell Daemon Configuration
mkdir -p "$CHROOT_PATH/run/sshd"
ln -sf /run/sshd "$CHROOT_PATH/var/run/sshd"

# Start sshd if it isn't already alive
if ! pgrep -x sshd > /dev/null; then
    echo "Starting sshd inside chroot..."
    chroot "$CHROOT_PATH" "$SSHD_BIN"
    echo "sshd started."
else
    echo "sshd is already running."
fi

# 8. Permissive context switch to bypass remaining FUSE/SELinux limits
setenforce 0
echo "Script finished successfully at $(date)"
