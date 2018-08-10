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
HDD=file=/dev/sdc,media=disk,format=raw,if=none
# HDD=file=/home/$USER/vm/windows.raw
OVMF_CODE=/usr/share/ovmf/x64/OVMF_CODE.fd
RAM=12G
CORES=12
RES="1920 1080"
videoid="10de 1184"
audioid="10de 0e0a"
usbid="1022 145f"
videobusid="0000:06:00.0"
audiobusid="0000:06:00.1"
usbbusid="0000:07:00.3"

# END Variables

## Kill X and related
systemctl stop lightdm > /dev/null 2>&1
killall i3 > /dev/null 2>&1
sleep 2

# Kill the console to free the GPU
echo 0 > /sys/class/vtconsole/vtcon0/bind
sleep 1
echo 0 > /sys/class/vtconsole/vtcon1/bind
sleep 1
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind
sleep 1

# Unload the Kernel Modules that use the GPU
modprobe -r nvidia_drm
sleep 1
modprobe -r nvidia_modeset
sleep 1
modprobe -r nvidia
sleep 1
modprobe -r snd_hda_intel
sleep 2

# Load the kernel module
modprobe vfio-pci
sleep 1

# Detach the GPU from drivers and attach to vfio. Also the usb.
echo $videoid > /sys/bus/pci/drivers/vfio-pci/new_id
sleep 1
echo $videobusid > /sys/bus/pci/devices/$videobusid/driver/unbind
sleep 1
echo $videobusid > /sys/bus/pci/drivers/vfio-pci/bind
sleep 1
echo $videoid > /sys/bus/pci/drivers/vfio-pci/remove_id
sleep 1

echo $audioid > /sys/bus/pci/drivers/vfio-pci/new_id
sleep 1
echo $audiobusid > /sys/bus/pci/devices/$audiobusid/driver/unbind
sleep 1
echo $audiobusid > /sys/bus/pci/drivers/vfio-pci/bind
sleep 1
echo $audioid > /sys/bus/pci/drivers/vfio-pci/remove_id
sleep 1

echo $usbid > /sys/bus/pci/drivers/vfio-pci/new_id
sleep 1
echo $usbbusid > /sys/bus/pci/devices/$usbbusid/driver/unbind
sleep 1
echo $usbbusid > /sys/bus/pci/drivers/vfio-pci/bind
sleep 1
echo $usbid > /sys/bus/pci/drivers/vfio-pci/remove_id
#ls -la /sys/bus/pci/devices/$usbbusid/
sleep 1

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
sleep 5

# Unload the vfio module. I am lazy, this leaves the GPU without drivers
modprobe -r vfio-pci
sleep 2

# Reload the kernel modules. This loads the drivers for the GPU
modprobe snd_hda_intel
sleep 5
modprobe nvidia_drm
sleep 2
modprobe nvidia_modeset
sleep 2
modprobe nvidia
sleep 5

# Bind the usb
#echo $usbid > /sys/bus/pci/drivers/xhci_hcd/new_id
echo $usbbusid > /sys/bus/pci/devices/$usbbusid/driver/unbind
echo $usbbusid > /sys/bus/pci/drivers/xhci_hcd/bind
sleep 10
#echo $usbid > /sys/bus/pci/drivers/xhci_hcd/remove_id
#ls -la /sys/bus/pci/devices/$usbbusid/

# Re-Bind EFI-Framebuffer and Re-bind to virtual consoles
# [Source] [https://github.com/joeknock90/Single-GPU-Passthrough/blob/master/README.md#vm-stop-script]
echo 1 > /sys/class/vtconsole/vtcon0/bind
sleep 1
echo 1 > tee /sys/class/vtconsole/vtcon1/bind
sleep 5
#echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind
#sleep 1

# Reload the Display Manager to access X
systemctl start lightdm
sleep 5

echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind
sleep 1
