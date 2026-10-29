#!/bin/bash
## Load the config file
source "/etc/libvirt/hooks/kvm.conf"
## 1. Stop mdadm array
if [ -b "$MD_DEVICE" ]; then
    mdadm --stop "$MD_DEVICE" > /dev/null 2>&1
fi
## 2. Detach loop devices
LOOP1=$(losetup -j "$EFI1_PATH" | cut -d: -f1)
if [ -n "$LOOP1" ]; then
    for dev in $LOOP1; do losetup -d "$dev"; done
fi
LOOP2=$(losetup -j "$EFI2_PATH" | cut -d: -f1)
if [ -n "$LOOP2" ]; then
    for dev in $LOOP2; do losetup -d "$dev"; done
fi
## 3. Deallocate Hugepages (free memory back to host)
echo 0 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
