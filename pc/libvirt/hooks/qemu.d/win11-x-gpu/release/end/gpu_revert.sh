#!/bin/bash
set -x

# 1. Unload VFIO-PCI Kernel Driver
modprobe -r vfio_pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

# 2. Re-Bind GPU to host
virsh nodedev-reattach pci_0000_01_00_1
virsh nodedev-reattach pci_0000_01_00_0

# 3. Reload Nvidia modules
modprobe nvidia
modprobe nvidia_modeset
modprobe nvidia_uvm
modprobe nvidia_drm

# 4. Rebind EFI-Framebuffer
nvidia-xconfig --query-gpu-info > /dev/null 2>&1
echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/bind

# 5. Rebind VT consoles
echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > /sys/class/vtconsole/vtcon1/bind

# Wait 2 seconds for modules to initialize
sleep 2

systemctl start keyd

# 6. Restart Display Manager
systemctl start sddm.service
