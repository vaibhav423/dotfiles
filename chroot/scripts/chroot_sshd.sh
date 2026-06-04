# Chroot SSHD boot script for Magisk - Fast Boot & FBE Aware
# Location: /data/adb/service.d/chroot_sshd.sh

# Configuration
CHROOT_PATH="/data/local/tmp/archl"
TERMUX_PREFIX="/data/data/com.termux/files"
BINDFS="$TERMUX_PREFIX/usr/bin/bindfs"
LIB_PATH="$TERMUX_PREFIX/usr/lib"
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
echo "System boot completed at $(date)."
sleep 10

# Apply SELinux policies early so the environment is fully prepped
echo "Applying SELinux policies..."
su -c "/data/adb/ap/bin/magiskpolicy --live 'allow untrusted_app_all shell_data_file dir { read write open getattr add_name create remove_name search }'" || true
su -c "/data/adb/ap/bin/magiskpolicy --live 'allow untrusted_app_all shell_data_file file { read write open getattr create unlink append }'" || true
su -c "/data/adb/ap/bin/magiskpolicy --live 'allow untrusted_app_all magisk unix_stream_socket { connectto read write getattr }'" || true

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
    
    # Create necessary directories
    mkdir -p "$CHROOT_PATH/termux-tmp" "$CHROOT_PATH/tmp" "$CHROOT_PATH/termux" "$CHROOT_PATH/sdcard" "$CHROOT_PATH/dev/shm" "$CHROOT_PATH/data/adb"
    
    # Pseudo-terminals and shared memory
    mount -t devpts devpts "$CHROOT_PATH/dev/pts"
    mount -t tmpfs -o size=256M tmpfs "$CHROOT_PATH/dev/shm"

    echo "Core mounts completed at $(date)."
else
    echo "Core mounts already active."
fi

# 3. START SSHD IMMEDIATELY
echo "Preparing SSHD..."
mkdir -p "$CHROOT_PATH/run/sshd"
ln -sf /run/sshd "$CHROOT_PATH/var/run/sshd"

# Check if sshd is already running using the chroot PID file
if [ ! -f "$CHROOT_PATH/var/run/sshd/sshd.pid" ] || ! kill -0 $(cat "$CHROOT_PATH/var/run/sshd/sshd.pid") 2>/dev/null; then
    echo "Starting sshd inside chroot..."
    chroot "$CHROOT_PATH" "$SSHD_BIN"
    echo "sshd started at $(date)."
else
    echo "sshd is already running."
fi

# 4. BACKGROUND THE FBE STORAGE MOUNTS
# This subshell runs in the background and waits for the device to be unlocked
(
        echo "Waiting for FBE Decryption (Checking CE storage directly)..."
    max_wait=150 

    # Check if the bindfs binary is readable. If it is, CE storage is decrypted.
    while [ ! -f "$BINDFS" ] && [ $max_wait -gt 0 ]; do
        sleep 2
        max_wait=$((max_wait - 1))
    done

    if [ -f "$BINDFS" ]; then
        echo "Decryption detected. Settling for 5 seconds..."
        sleep 5

        echo "Setting up Termux ,fire & bindfs mounts..."

        chmod -R 777 "$TERMUX_PREFIX/usr/tmp"
        mount --bind "$TERMUX_PREFIX/usr/tmp" "$CHROOT_PATH/tmp"
        LD_LIBRARY_PATH="$LIB_PATH" "$BINDFS" -o suid -u $UID_FIRE -g $GID_FIRE /data "$CHROOT_PATH/data"

        su -mm -c "mount --bind /data/media/0 $CHROOT_PATH/sdcard"
        su -mm -c "mount --bind $CHROOT_PATH/home/fire/Water/Fire /sdcard/Documents/Fire"
        su -mm -c "mount --bind $CHROOT_PATH/home/fire/Water/Fire $CHROOT_PATH/sdcard/Documents/Fire"

        echo "FBE mounts completed successfully at $(date)."
    else
        echo "Timed out waiting for FBE decryption at $(date)."
    fi

) &

echo "Main boot script finished successfully at $(date). Storage mounts are running in the background."
