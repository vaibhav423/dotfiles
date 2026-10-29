#!/bin/bash
# Helpful to read output when debugging
set -x

# 1. Stop display manager
systemctl stop sddm.service

# 2. Aggressively kill lingering Wayland/X11 processes
killall -9 Hyprland Xwayland Xorg sddm-helper
systemctl stop keyd

# 3. FORCE KILL anything holding the GPU devices open
# This is the critical fix for the libaquamarine/Hyprland segfault.
# It forces the kernel to close the dangling DRM leases.
fuser -k -9 /dev/dri/card* 2>/dev/null
fuser -k -9 /dev/nvidia* 2>/dev/null

# 4. Wait for the kernel to clean up the closed file descriptors
sleep 3

# 5. Unbind VTconsoles
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind

# 6. Unbind EFI-Framebuffer
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

# Wait another moment for framebuffer to release
sleep 2

# 7. Explicitly unload Nvidia drivers
modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r nvidia_uvm
modprobe -r nvidia

# 8. Unbind the GPU from the host (hand it to libvirt)
virsh nodedev-detach pci_0000_01_00_0
virsh nodedev-detach pci_0000_01_00_1

# 9. Load VFIO Kernel Modules
modprobe vfio
modprobe vfio_pci
modprobe vfio_iommu_type1
