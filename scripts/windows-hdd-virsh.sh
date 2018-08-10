#!/bin/bash

# Check if the script is executed as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
# END Check if you are sudo

# Variables
USER=yu
IOMMU_GPU=06:00.0
IOMMU_GPU_AUDIO=06:00.1
IOMMU_USB=07:00.3
VIRSH_GPU=pci_0000_06_00_0
VIRSH_GPU_AUDIO=pci_0000_06_00_1
VIRSH_USB=pci_0000_07_00_3
VBIOS=/home/$USER/vm/GK104_80.04.C3.00.0F-MODED.rom
IMG=file=/home/$USER/vm/windows.raw,id=disk,format=raw,if=none
ISO=/home/yu/vm/win10.iso
HDD=file=/dev/sdc,media=disk
# HDD=file=/home/$USER/vm/windows.raw
OVMF_CODE=/usr/share/ovmf/x64/OVMF_CODE.fd
RAM=12G
CORES=12
RES="1920 1080"
# END Variables

## Kill X and related
systemctl stop lightdm
killall i3
sleep 2

# Unload the Kernel Modules that use the GPU
modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r nvidia
modprobe -r snd_hda_intel

# Kill the console to free the GPU
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

# Detach the GPU from host
virsh nodedev-detach $VIRSH_GPU > /dev/null 2>&1
virsh nodedev-detach $VIRSH_GPU_AUDIO > /dev/null 2>&1
virsh nodedev-detach $VIRSH_USB > /dev/null 2>&1

# QEMU (VM) command
qemu-system-x86_64 -enable-kvm \
    -nographic -vga none -parallel none -serial none \
    -enable-kvm \
    -m $RAM \
    -cpu host,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_time,hv_vapic,hv_vendor_id=0xDEADBEEFFF \
    -rtc clock=host,base=localtime \
    -smp $CORES,sockets=1,cores=$CORES,threads=0 \
    -device vfio-pci,host=$IOMMU_GPU,multifunction=on,x-vga=on,romfile=$VBIOS \
    -device vfio-pci,host=$IOMMU_GPU_AUDIO \
    -device vfio-pci,host=$IOMMU_USB \
    -drive if=pflash,format=raw,readonly,file=$OVMF_CODE \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-hd,bus=scsi0.0,drive=rootfs \
    -drive id=rootfs,$HDD > /dev/null 2>&1 &
# END QEMU (VM) command

# Wait for QEMU to finish before continue
wait

# Reattach the GPU to the host
virsh nodedev-reattach $VIRSH_USB > /dev/null 2>&1
virsh nodedev-reattach $VIRSH_GPU_AUDIO > /dev/null 2>&1
virsh nodedev-reattach $VIRSH_GPU > /dev/null 2>&1

# Set console resolution
fbset -xres $(echo "$RES" | awk '{print $1}') -yres $(echo "$RES" | awk '{print $2}')

# Re-Bind EFI-Framebuffer and Re-bind to virtual consoles
# [Source] [https://github.com/joeknock90/Single-GPU-Passthrough/blob/master/README.md#vm-stop-script]
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind
echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > tee /sys/class/vtconsole/vtcon1/bind

# Reload the kernel modules
modprobe snd_hda_intel
modprobe nvidia_drm
modprobe nvidia_modeset
modprobe nvidia

# Reload the Display Manager to access X
systemctl start lightdm
