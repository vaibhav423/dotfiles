chrootpath="/data/local/tmp/archl"

ubset() {
    if ! su -c "grep -q \"$chrootpath\" /proc/mounts"; then
        su -c "mount -o remount,dev,suid,exec /data"
        su -c "mount --rbind /dev $chrootpath/dev"
        su -c "mount --bind /sys $chrootpath/sys"
        su -c "mount --bind /proc $chrootpath/proc"
        su -c "mount --bind /system $chrootpath/system"
        su -c "mount --rbind /apex $chrootpath/apex"
        su -c "mount --bind /linkerconfig $chrootpath/linkerconfig"
        su -c "mkdir -p $chrootpath/tmp $chrootpath/termux $chrootpath/sdcard $chrootpath/dev/shm"
        su -c "mount -t devpts devpts $chrootpath/dev/pts"
        su -c "mount -t tmpfs -o size=256M tmpfs $chrootpath/dev/shm"
        sudo bindfs -u 1001 -g 984 /data/data/com.termux/files "${chrootpath}/termux"
        sudo bindfs -u 1001 -g 984 /sdcard "$chrootpath/sdcard"
        su -c "mount --bind /data/data/com.termux/files/usr/tmp $chrootpath/tmp"
        #sudo bindfs -u 1001 -g 984 /data/data/com.termux/files/usr/tmp "${chrootpath}/tmp"
        # echo "mount done"
    # else
    #      echo "mount already done"
    fi
}

ubset



#wrapper
if [ "$1" = "-c" ]; then
    shift 
    COMMAND_TO_RUN="$*"
    # This version matches the working interactive case as closely as possible.
    # We use script inside the chroot, and su -l fire to run the command.
    # We explicitly set TERM to ensure nvim knows the terminal type.
    su -c "chroot $chrootpath /usr/bin/env TERM=${TERM:-xterm-256color} SHELL=/usr/bin/zsh /usr/bin/script -q -c \"/usr/bin/su -l fire -c 'exec /usr/bin/zsh -c \\\"exec $COMMAND_TO_RUN\\\"'\""
else
    # This is the interactive version you said works properly.
    su -c "chroot $chrootpath /usr/bin/env SHELL=/usr/bin/bash /usr/bin/script -q -c '/usr/bin/su -l fire' "
fi
# this command works proper
#/debug_ramdisk/su -c "chroot $chrootpath /usr/bin/env SHELL=/usr/bin/bash /usr/bin/script -q -c '/usr/bin/su -l fire' "
# this shows ttyname error
#/debug_ramdisk/su -c "chroot $chrootpath /usr/bin/su - fire" 
# these brings two nested shells
#su -c "chroot /data/local/tmp/archl /usr/bin/su fire" < /dev/tty 2>&1 && exit t
#su -c "chroot /data/local/tmp/archl /usr/bin/su fire" > /dev/tty && exit 

