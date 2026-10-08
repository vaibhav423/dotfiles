#!/system/bin/sh
# Bare chroot -> minimal interactive shell as `fire`
#
# Must be run as root (chroot needs CAP_SYS_CHROOT):
#   su -c 'sh /path/to/chroot_bare.sh'
# No su is used *by* this script; it expects to already have root.
#
# Mounts: /proc (zsh process substitution), devpts (tty/ZLE), /dev/null (mknod).
# No /dev rbind, no /sys, no /data -- so ~/Water and the ~/.config/zshrc
# symlink into it are NOT reachable.

CHROOT_PATH="/data/local/tmp/archl"
UID_FIRE=1000
GID_FIRE=1000

is_mounted() {
    awk -v p="$CHROOT_PATH/$1" '$2==p { f=1 } END { exit !f }' /proc/mounts
}

# zsh uses /proc/self/fd/N for process substitution; without it .zshrc dies early
if ! is_mounted proc; then
    mkdir -p "$CHROOT_PATH/proc"
    mount --bind /proc "$CHROOT_PATH/proc"
fi

# oh-my-zsh and zsh-syntax-highlighting both bail on a missing /dev/null
# (a mount --bind of a char device fails on Android, so make the node instead)
if [ ! -c "$CHROOT_PATH/dev/null" ]; then
    mkdir -p "$CHROOT_PATH/dev"
    mknod "$CHROOT_PATH/dev/null" c 1 3
    chmod 666 "$CHROOT_PATH/dev/null"
fi

# a real tty, or zle and job control don't work
if ! is_mounted dev/pts; then
    mkdir -p "$CHROOT_PATH/dev/pts"
    mount -t devpts devpts "$CHROOT_PATH/dev/pts"
fi

PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
HOME=/home/fire
USER=fire
LOGNAME=fire
TERM="${TERM:-xterm-256color}"

# $SHELL only records what you *were*, not what runs -- read the real one
LOGIN_SHELL="$(awk -F: -v u="$UID_FIRE" '$3==u { print $7; exit }' "$CHROOT_PATH/etc/passwd")"
[ -x "$CHROOT_PATH$LOGIN_SHELL" ] || LOGIN_SHELL=/bin/bash
SHELL="$LOGIN_SHELL"
export PATH HOME USER LOGNAME SHELL TERM

if [ "$#" -eq 0 ]; then
    set -- /bin/sh -c 'cd "$HOME" || cd /; exec "$SHELL" -l'
fi

# toybox chroot has no --userspec, so drop privileges inside via setpriv
# (Arch's su would need PAM + /dev, neither of which we mount here)
exec chroot "$CHROOT_PATH" /usr/bin/setpriv \
    --reuid="$UID_FIRE" --regid="$GID_FIRE" --init-groups "$@"