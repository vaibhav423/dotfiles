#!/system/bin/sh
# Chroot SSHD boot script for Magisk - Stability Enhanced
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
echo "System boot completed."

# 2. Wait for /sdcard to be fully mounted by the system
# We check /proc/mounts to ensure it's not just a symlink but an actual mount point
echo "Waiting for /storage/emulated/0 to appear in /proc/mounts..."
max_wait=30
while ! grep -q "/storage/emulated/0" /proc/mounts && [ $max_wait -gt 0 ]; do
    sleep 2
    max_wait=$((max_wait - 1))
done

# 3. Final settle delay
# Gives the Media Provider and other services a few seconds to finish their work
echo "Settling for 5 seconds..."
sleep 5

# Ensure mounts are active
if ! grep -q "$CHROOT_PATH/proc" /proc/mounts; then
    echo "Setting up mounts for $CHROOT_PATH..."
    mount -o remount,dev,suid,exec /data
    
    # Core mounts
    mount --rbind /dev "$CHROOT_PATH/dev"
    mount --bind /sys "$CHROOT_PATH/sys"
    mount --bind /proc "$CHROOT_PATH/proc"
    mount --bind /system "$CHROOT_PATH/system"
    mount --rbind /apex "$CHROOT_PATH/apex"
    mount --bind /linkerconfig "$CHROOT_PATH/linkerconfig"

    
    mkdir -p "$CHROOT_PATH/termux-tmp" "$CHROOT_PATH/tmp" "$CHROOT_PATH/termux" "$CHROOT_PATH/sdcard" "$CHROOT_PATH/dev/shm" "$CHROOT_PATH/data/adb"
    mount -t devpts devpts "$CHROOT_PATH/dev/pts"
    mount -t tmpfs -o size=256M tmpfs "$CHROOT_PATH/dev/shm"
    
    # bindfs mounts with stability check
    # We use /storage/emulated/0 directly as it's more stable than the /sdcard symlink
    #echo "Mounting bindfs..."
    #LD_LIBRARY_PATH="$LIB_PATH" "$BINDFS" -u $UID_FIRE -g $GID_FIRE "$TERMUX_PREFIX" "$CHROOT_PATH/termux"
    #use link to /data/data instead
    #LD_LIBRARY_PATH="$LIB_PATH" "$BINDFS" -u $UID_FIRE -g $GID_FIRE "$TERMUX_PREFIX/usr/tmp" "$CHROOT_PATH/tmp"
    chmod -R 777 $TERMUX_PREFIX/usr/tmp
    mount --bind "$TERMUX_PREFIX/usr/tmp" "$CHROOT_PATH/tmp"

    #LD_LIBRARY_PATH="$LIB_PATH" "$BINDFS" -u $UID_FIRE -g $GID_FIRE /storage/emulated/0 "$CHROOT_PATH/sdcard"
    #mount --bind /storage/emulated/0 "$CHROOT_PATH/sdcard"
    #mount --bind "$CHROOT_PATH/home/fire/Water/Fire" $TERMUX_PREFIX/home/Water/Fire 

    # sdcard
    su -mm -c "mount --bind /data/media/0 /data/local/tmp/archl/sdcard"
    # fire
    su -mm -c "mount --bind /data/local/tmp/archl/home/fire/Water/Fire /data/media/0/Documents/Fire"
    # data
    LD_LIBRARY_PATH="$LIB_PATH" "$BINDFS" -u $UID_FIRE -g $GID_FIRE /data "$CHROOT_PATH/data"
    #su -mm -c "mount --bind /data/local/tmp/archl/home/fire/Water/Fire  /sdcard/Documents/Fire"

    #mount --bind /data/adb "$CHROOT_PATH/data/adb" 
    # useful for termux - x11
    echo "Mounts completed."
else
    echo "Mounts already active."
fi

<<<<<<< HEAD
# # 6. Final Permission & Ownership Alignment
# # Since 'fire' is UID 1000, we match it to the Android system user/media groups
# chown -R 1000:1023 "$CHROOT_PATH/home/fire/Water/Fire"
# chmod -R 2775 "$CHROOT_PATH/home/fire/Water/Fire"

# 7. Secure Shell Daemon Configuration
=======
# Ensure sshd run dir exists inside chroot and has correct symlink
>>>>>>> 4d45fb5eefa06bda89d904788dc43afa9eac4e31
mkdir -p "$CHROOT_PATH/run/sshd"
ln -sf /run/sshd "$CHROOT_PATH/var/run/sshd"

# Start sshd if not already running
# We check both the PID and the listener state
if ! pgrep -x sshd > /dev/null; then
    echo "Starting sshd inside chroot..."
    # We use -D to keep it in the foreground for a second to catch immediate errors, 
    # then let it background naturally if we remove -D. 
    # But standard sshd backgrounding is fine for Magisk service.d.
    chroot "$CHROOT_PATH" "$SSHD_BIN"
    echo "sshd started."
else
    echo "sshd is already running."
fi

<<<<<<< HEAD
# 8. Permissive context switch to bypass remaining FUSE/SELinux limits
# setenforce 0
echo "Script finished successfully at $(date)"


Still none of these worked tried the am , sync here is my script

#!/system/bin/sh
# Chroot SSHD boot script for Magisk - Stability Enhanced
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
echo "System boot completed."

# 2. Wait for /sdcard to be fully mounted by the system
# We check /proc/mounts to ensure it's not just a symlink but an actual mount point
echo "Waiting for /storage/emulated/0 to appear in /proc/mounts..."
max_wait=30
while ! grep -q "/storage/emulated/0" /proc/mounts && [ $max_wait -gt 0 ]; do
    sleep 2
    max_wait=$((max_wait - 1))
done

# 3. Final settle delay
# Gives the Media Provider and other services a few seconds to finish their work
echo "Settling for 5 seconds..."
sleep 5

# Ensure mounts are active
if ! grep -q "$CHROOT_PATH/proc" /proc/mounts; then
    echo "Setting up mounts for $CHROOT_PATH..."
    mount -o remount,dev,suid,exec /data
    
    # Core mounts
    mount --rbind /dev "$CHROOT_PATH/dev"
    mount --bind /sys "$CHROOT_PATH/sys"
    mount --bind /proc "$CHROOT_PATH/proc"
    mount --bind /system "$CHROOT_PATH/system"
    mount --rbind /apex "$CHROOT_PATH/apex"
    mount --bind /linkerconfig "$CHROOT_PATH/linkerconfig"
    #mount --bind /storage/emulated/0 "$CHROOT_PATH/sdcard"
    su -mm -c "mount --bind /data/media/0 /data/local/tmp/archl/sdcard"
    su -mm -c "mount --bind /data/local/tmp/archl/home/fire/Water/Fire /data/media/0/Documents/Fire"


    #mount --bind "$CHROOT_PATH/home/fire/Water/Fire" $TERMUX_PREFIX/home/Water/Fire 

    
    mkdir -p "$CHROOT_PATH/termux-tmp" "$CHROOT_PATH/tmp" "$CHROOT_PATH/termux" "$CHROOT_PATH/sdcard" "$CHROOT_PATH/dev/shm" "$CHROOT_PATH/data/adb"
    mount -t devpts devpts "$CHROOT_PATH/dev/pts"
    mount -t tmpfs -o size=256M tmpfs "$CHROOT_PATH/dev/shm"
    
    # bindfs mounts with stability check
    # We use /storage/emulated/0 directly as it's more stable than the /sdcard symlink
    #echo "Mounting bindfs..."
    #LD_LIBRARY_PATH="$LIB_PATH" "$BINDFS" -u $UID_FIRE -g $GID_FIRE "$TERMUX_PREFIX" "$CHROOT_PATH/termux"
    #use link to /data/data instead
    #LD_LIBRARY_PATH="$LIB_PATH" "$BINDFS" -u $UID_FIRE -g $GID_FIRE "$TERMUX_PREFIX/usr/tmp" "$CHROOT_PATH/tmp"
    chmod -R 777 $TERMUX_PREFIX/usr/tmp
    mount --bind "$TERMUX_PREFIX/usr/tmp" "$CHROOT_PATH/tmp"

    #LD_LIBRARY_PATH="$LIB_PATH" "$BINDFS" -u $UID_FIRE -g $GID_FIRE /storage/emulated/0 "$CHROOT_PATH/sdcard"
    LD_LIBRARY_PATH="$LIB_PATH" "$BINDFS" -u $UID_FIRE -g $GID_FIRE /data "$CHROOT_PATH/data"
    #su -mm -c "mount --bind /data/local/tmp/archl/home/fire/Water/Fire  /sdcard/Documents/Fire"

    #mount --bind /data/adb "$CHROOT_PATH/data/adb" 
    # useful for termux - x11
    echo "Mounts completed."
else
    echo "Mounts already active."
fi

# Ensure sshd run dir exists inside chroot and has correct symlink
mkdir -p "$CHROOT_PATH/run/sshd"
ln -sf /run/sshd "$CHROOT_PATH/var/run/sshd"

# Start sshd if not already running
# We check both the PID and the listener state
if ! pgrep -x sshd > /dev/null; then
    echo "Starting sshd inside chroot..."
    # We use -D to keep it in the foreground for a second to catch immediate errors, 
    # then let it background naturally if we remove -D. 
    # But standard sshd backgrounding is fine for Magisk service.d.
    chroot "$CHROOT_PATH" "$SSHD_BIN"
    echo "sshd started."
else
    echo "sshd is already running."
fi

setenforce 0
=======
# setenforce 0
su -c "magiskpolicy --live 'allow untrusted_app_all shell_data_file dir { read write open getattr add_name create remove_name search }'"
su -c "magiskpolicy --live 'allow untrusted_app_all shell_data_file file { read write open getattr create unlink append }'"
>>>>>>> 4d45fb5eefa06bda89d904788dc43afa9eac4e31
echo "Script finished successfully at $(date)"
