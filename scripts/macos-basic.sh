#!/bin/bash

## Check if the script was executed as root
[[ "$EUID" -ne 0 ]] && echo "Please run as root" && exit 1

## Load the config file
source "${BASH_SOURCE%/*}/config"

## Memory lock limit
[[ $ULIMIT != $ULIMIT_TARGET ]] && ulimit -l $ULIMIT_TARGET

## Kill the Display Manager
systemctl stop lightdm
sleep 1

## Remove the framebuffer and console
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

# Unload the Kernel Modules that use the GPU
modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r nvidia
modprobe -r snd_hda_intel

# Load the kernel module
modprobe vfio-pci

## Detach the GPU
echo $videoid > /sys/bus/pci/drivers/vfio-pci/new_id
echo $videobusid > /sys/bus/pci/devices/$videobusid/driver/unbind
echo $videobusid > /sys/bus/pci/drivers/vfio-pci/bind
echo $videoid > /sys/bus/pci/drivers/vfio-pci/remove_id

echo $audioid > /sys/bus/pci/drivers/vfio-pci/new_id
echo $audiobusid > /sys/bus/pci/devices/$audiobusid/driver/unbind
echo $audiobusid > /sys/bus/pci/drivers/vfio-pci/bind
echo $audioid > /sys/bus/pci/drivers/vfio-pci/remove_id

# QEMU (VM) command
qemu-system-x86_64 -runas $VM_USER -enable-kvm \
  -nographic -vga none -parallel none -serial none \
  -m $MACOS_RAM \
  -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,$MACOS_OPTIONS\
  -machine pc-q35-2.11 \
  -smp $MACOS_CORES,sockets=1,cores=$(( $MACOS_CORES / 2 )),threads=2 \
  -device vfio-pci,host=$IOMMU_GPU,multifunction=on,x-vga=on,romfile=$VBIOS \
  -device vfio-pci,host=$IOMMU_GPU_AUDIO \
  -usb -device usb-kbd -device usb-tablet \
  -device nec-usb-xhci,id=xhci \
  -netdev user,id=net0 \
  -device e1000-82545em,netdev=net0,id=net0,mac=52:54:00:c9:18:27 \
  -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
  -drive if=pflash,format=raw,readonly,file=$MACOS_OVMF \
  -drive if=pflash,format=raw,file=$MACOS_OVMF_VARS \
  -smbios type=2 \
  -device ide-drive,bus=ide.2,drive=Clover \
  -drive id=Clover,if=none,snapshot=on,format=qcow2,file=$MACOS_CLOVER \
  -device ide-drive,bus=ide.0,drive=ISO \
  -drive id=ISO,if=none,snapshot=on,media=cdrom,file=$MACOS_ISO \
  -device ide-drive,bus=ide.1,drive=HDD \
  -drive id=HDD,file=$MACOS_IMG,media=disk,format=raw,if=none >> $LOG 2>&1 &

# Wait for QEMU
wait

## Unload vfio
modprobe -r vfio-pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

# Reload the kernel modules
modprobe snd_hda_intel
modprobe nvidia_drm
modprobe nvidia_modeset
modprobe nvidia

## Reload the framebuffer and console
echo 1 > /sys/class/vtconsole/vtcon0/bind
nvidia-xconfig --query-gpu-info > /dev/null 2>&1
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind

# Reload the Display Manager to access X
systemctl start lightdm

# Restore ulimit
ulimit -l $ULIMIT
