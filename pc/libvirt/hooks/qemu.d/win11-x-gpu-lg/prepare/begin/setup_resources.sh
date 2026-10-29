#!/bin/bash
source "/etc/libvirt/hooks/kvm.conf"

## 1. Allocate Hugepages (18GB = 9000 pages of 2MB) with retry + compaction
HUGEPAGES=9000
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory
sleep 2

echo "$HUGEPAGES" > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Retry up to 10 times if we didn't get all pages
for i in $(seq 1 10); do
    CURRENT=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages)
    if [ "$CURRENT" -ge "$HUGEPAGES" ]; then
        break
    fi
    echo 1 > /proc/sys/vm/compact_memory
    sleep 2
    echo "$HUGEPAGES" > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
done

ALLOCATED=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages)
if [ "$ALLOCATED" -lt "$HUGEPAGES" ]; then
    echo "ERROR: Only allocated $ALLOCATED/$HUGEPAGES hugepages" >&2
    exit 1
fi

## 2. Load necessary kernel modules
modprobe loop
modprobe linear

## 3. Setup Loop Devices (only if not already attached)
LOOP1=$(losetup -j "$EFI1_PATH" | cut -d: -f1 | head -n1)
if [ -z "$LOOP1" ]; then
    LOOP1=$(losetup -f)
    losetup "$LOOP1" "$EFI1_PATH"
fi
LOOP2=$(losetup -j "$EFI2_PATH" | cut -d: -f1 | head -n1)
if [ -z "$LOOP2" ]; then
    LOOP2=$(losetup -f)
    losetup "$LOOP2" "$EFI2_PATH"
fi

## 4. Build the linear array
mdadm --build --verbose "$MD_DEVICE" --chunk=512 --level=linear --raid-devices=3 "$LOOP1" "$ARRAY_PARTITION" "$LOOP2" > /dev/null 2>&1
