# Vector (LSPosed) dex2oat Mount Hide

Hides Vector's global `dex2oat` bind mounts from mountinfo scanners (e.g. Duck Detector) by removing the `/adb/` token from all mount fields.

---

## The Problem

Vector's daemon (`daemon.apk` JNI `doMountNative`) enters the init mount namespace (`/proc/1/ns/mnt`) and bind-mounts wrapper binaries over `/apex/com.android.art/bin/dex2oat{32,64}`.

Because the source binaries live in `/data/adb/modules/zygisk_vector/bin/`, the resulting mounts expose `/adb/` in both `root` and `point` fields across all namespaces, triggering root/ADB detection:
- `root=/adb/modules/zygisk_vector/bin/dex2oat*`
- `point=/apex/com.android.art/bin/dex2oat*`

---

## How It Works

A single script at `/data/adb/post-fs-data.d/vector_hide_dex2oat.sh`:

1. **Preempts the daemon (`post-fs-data`)**:
   - Copies dex2oat wrappers to `/data/local/vector-bin/` (preserving SELinux context `dex2oat_exec`).
   - Bind-mounts them over `$MODDIR/bin/dex2oat*`.
   - When Vector's daemon starts and calls `realpath("bin/dex2oat*")`, it resolves to `/local/vector-bin/...`.
   - The daemon's `/apex` mounts are created with `root=/local/vector-bin/...` from the start.

2. **Cleans up redirect mounts (`service.d`)**:
   - The temporary bind mounts on `$MODDIR/bin/` contain `/adb/` in their `point` field.
   - A one-shot cleanup script in `service.d` runs after boot and removes them using `umount -l` (lazy unmount required due to `shared:37` propagation).
   - Only the clean `/apex` mounts remain.

---

## Installation (New Device)

1. Flash Vector (`zygisk_vector`) in APatch / KernelSU / Magisk and reboot once.
2. Install `vector_hide_dex2oat.sh`:

```sh
# Push and install the script
adb push vector_hide_dex2oat.sh /data/local/tmp/
adb shell 'su -c "cp /data/local/tmp/vector_hide_dex2oat.sh /data/adb/post-fs-data.d/ && chmod 755 /data/adb/post-fs-data.d/vector_hide_dex2oat.sh"'

# Reboot
adb reboot
```

The script automatically handles Vector updates (re-copies new binaries on each boot).

---

## Verification

After boot completes:

```sh
# 1. Global /adb/ token count must be 0
adb shell 'su -c "grep -c /adb/ /proc/self/mountinfo"'
# Expected: 0

# 2. dex2oat root paths must point to /local/vector-bin/
adb shell 'su -c "grep dex2oat /proc/self/mountinfo | awk \"{print \$4, \$5}\""'
# Expected:
# /local/vector-bin/dex2oat32 /apex/com.android.art/bin/dex2oat32
# /local/vector-bin/dex2oat64 /apex/com.android.art/bin/dex2oat64
```
