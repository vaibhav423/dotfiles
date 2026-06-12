# Chroot SSHD boot script for Magisk - Fast Boot & FBE Aware
# Location: /data/adb/service.d/chroot_sshd.sh

# Configuration
CHROOT_PATH="/data/local/tmp/archl"
TERMUX_PREFIX="/data/data/com.termux/files"
# Use chroot's own bindfs - independent of Termux process lifetime
#BINDFS="$TERMUX_PREFIX/usr/bin/bindfs"
#LIB_PATH="$TERMUX_PREFIX/usr/lib"
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
    mkdir -p "$CHROOT_PATH/termux-tmp" "$CHROOT_PATH/tmp" "$CHROOT_PATH/sdcard" "$CHROOT_PATH/dev/shm" "$CHROOT_PATH/data/adb"

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

if [ ! -f "$CHROOT_PATH/var/run/sshd/sshd.pid" ] || ! kill -0 $(cat "$CHROOT_PATH/var/run/sshd/sshd.pid") 2>/dev/null; then
    echo "Starting sshd inside chroot..."
    chroot "$CHROOT_PATH" "$SSHD_BIN"
    echo "sshd started at $(date)."
else
    echo "sshd is already running."
fi

# 4. BACKGROUND THE FBE STORAGE MOUNTS
(
    echo "Waiting for FBE Decryption (CE storage)..."
    max_wait=150

    # CE storage is unlocked when /data/data is readable (not just mounted)
    while [ $max_wait -gt 0 ]; do
        if ls /data/data/com.termux >/dev/null 2>&1; then
            break
        fi
        sleep 2
        max_wait=$((max_wait - 1))
    done

    if ls /data/data/com.termux >/dev/null 2>&1; then
        echo "Decryption detected. Settling for 5 seconds..."
        sleep 5

        echo "Setting up Termux & bindfs mounts..."

        # X11 socket bridge
        chmod -R 777 "$TERMUX_PREFIX/usr/tmp" 2>/dev/null || true
        mount --bind "$TERMUX_PREFIX/usr/tmp" "$CHROOT_PATH/termux-tmp"
        mkdir -p "$TERMUX_PREFIX/usr/tmp/.X11-unix" "$CHROOT_PATH/tmp/.X11-unix"
        mount --bind "$TERMUX_PREFIX/usr/tmp/.X11-unix" "$CHROOT_PATH/tmp/.X11-unix"

        # Mount /data into chroot using chroot's own bindfs - never dies with Termux
        #LD_LIBRARY_PATH="$LIB_PATH" "$BINDFS" -o suid -u $UID_FIRE -g $GID_FIRE /data "$CHROOT_PATH/data"

        #"$ARCH_LINKER" --library-path "$LIB_PATH" "$BINDFS" -o suid -u $UID_FIRE -g $GID_FIRE /data "$CHROOT_PATH/data"

        #LD_LIBRARY_PATH="$LIB_PATH" "$BINDFS" -o suid -u $UID_FIRE -g $GID_FIRE /data "$CHROOT_PATH/data"

        mount --bind /data "$CHROOT_PATH/data"
        su -mm -c "mount --bind /sdcard $CHROOT_PATH/sdcard"
        su -mm -c "mount --bind $CHROOT_PATH/home/fire/Water/Fire /sdcard/Documents/Fire"

        echo "FBE mounts completed successfully at $(date)."
    else
        echo "Timed out waiting for FBE decryption at $(date)."
    fi
) &

echo "-----------------------------------------------------------------------------------------------"
echo "Main boot script finished successfully at $(date). Storage mounts are running in the background."
echo "-----------------------------------------------------------------------------------------------"
