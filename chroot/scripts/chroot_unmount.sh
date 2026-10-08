#!/system/bin/sh
# Tear down chroot_min.sh's bind-mounts. Lazy detach, safe to re-run.
# Usage: sh chroot_unmount.sh [-n]     -n = list only, touch nothing

CHROOT_PATH="/data/local/tmp/archl"

if [ "$1" = "-n" ]; then
    DRYRUN=1
else
    DRYRUN=""
    # dev/pts before dev: it's a child of the /dev rbind
    for m in dev/pts dev sys proc data; do
        umount -l "$CHROOT_PATH/$m" 2>/dev/null
    done
fi

# sweep: submounts from an rbind outlive a lazy parent detach, and their
# paths are then unreachable -- so this is the only way to clear them.
# deepest first, one awk instead of a fork per PID.
targets=$(awk -v p="$CHROOT_PATH" '
    $2 == p || index($2, p "/") == 1 {
        n = gsub(/\//, "/", $2)
        print n "\t" $2
    }' /proc/mounts | sort -rn | cut -f2)

if [ -z "$targets" ]; then
    echo "clean"
    exit 0
fi

echo "$targets" | while read -r m; do
    [ -n "$m" ] || continue
    if [ -n "$DRYRUN" ]; then
        echo "would detach: $m"
    else
        umount -l "$m" 2>/dev/null || echo "FAILED $m" >&2
    fi
done

if [ -z "$DRYRUN" ]; then
    left=$(awk -v p="$CHROOT_PATH" '$2 == p || index($2, p "/") == 1' /proc/mounts)
    [ -n "$left" ] && { echo "still mounted:" >&2; echo "$left" >&2; }
fi
exit 0