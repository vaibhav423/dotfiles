#!/bin/bash
## Load the config file
source "/etc/libvirt/hooks/kvm.conf"
## 1. Allocate Hugepages
echo "$HUGEPAGES_AMOUNT" > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
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
