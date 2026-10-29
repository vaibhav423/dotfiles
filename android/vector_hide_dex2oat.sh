#!/system/bin/sh
# /data/adb/post-fs-data.d/vector_hide_dex2oat.sh
#
# Runs at post-fs-data (before Vector daemon starts).
# 1. Copies Vector's dex2oat wrappers to /data/local/vector-bin
# 2. Bind-mounts them over $MODDIR/bin/dex2oat* so the daemon's realpath()
#    resolves to /local/vector-bin/ instead of /adb/modules/...
#    -> the apex mounts the daemon places will have root=/local/vector-bin/...
# 3. Writes a service-stage cleanup script that lazy-unmounts the bin/ redirect
#    mounts after the daemon has finished its apex mounts.
#    (bin/ mounts have /adb/ in their target path; must be removed.
#     umount -l is required because the mounts are shared:37 propagation.)

DST=/data/local/vector-bin
SRC=/data/adb/modules/zygisk_vector/bin

[ -f "$SRC/dex2oat32" ] || exit 0

mkdir -p "$DST"
cp -f "$SRC/dex2oat32" "$DST/dex2oat32"
cp -f "$SRC/dex2oat64" "$DST/dex2oat64"
chcon u:object_r:dex2oat_exec:s0 "$DST/dex2oat32" "$DST/dex2oat64"
chmod 755 "$DST/dex2oat32" "$DST/dex2oat64"

# Pre-empt the daemon: redirect its bin/ files to the clean source path
mount -o bind "$DST/dex2oat32" "$SRC/dex2oat32"
mount -o bind "$DST/dex2oat64" "$SRC/dex2oat64"

# Write a one-shot service script that removes the bin/ redirect mounts
# after Vector's daemon has placed its apex mounts with clean roots.
cat > /data/adb/service.d/vector_bin_cleanup.sh << 'EOF'
#!/system/bin/sh
SRC=/data/adb/modules/zygisk_vector/bin

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 8

# lazy-unmount is required: these mounts are shared:37 propagation,
# plain umount returns EBUSY and leaves the /adb/ target path visible to scanners
umount -l "$SRC/dex2oat32" 2>/dev/null
umount -l "$SRC/dex2oat64" 2>/dev/null

# Self-delete — post-fs-data.d script recreates this every boot
rm -f /data/adb/service.d/vector_bin_cleanup.sh
EOF
chmod 755 /data/adb/service.d/vector_bin_cleanup.sh
