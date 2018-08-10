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
IMG=/home/$USER/vm/mac-hs.raw,id=disk,format=raw,if=none
CLOVER=/home/$USER/vm/Clover-1080.qcow2
ISO=/home/$USER/vm/HighSierra-10.13.6-qemu.iso
#HDD=file=/dev/sdc,media=disk
HDD=file=/home/$USER/vm/mac-hs.raw
OVMF_CODE=/usr/share/ovmf/x64/OVMF_CODE.fd
RAM=12G
CORES=4
videoid="10de 1184"
audioid="10de 0e0a"
usbid="1022 145f"
videobusid="0000:06:00.0"
audiobusid="0000:06:00.1"
usbbusid="0000:07:00.3"
#RES="1920 1080"
# END Variables

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
MY_OPTIONS="+aes,+xsave,+avx,+xsaveopt,avx2,+smep"

qemu-system-x86_64 -enable-kvm \
    -nographic -vga none -parallel none -serial none \
    -m $RAM \
    -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,$MY_OPTIONS\
    -machine pc-q35-2.9 \
    -smp $CORES,cores=$CORES \
    -device vfio-pci,host=$IOMMU_GPU,multifunction=on,x-vga=on,romfile=$VBIOS \
    -device vfio-pci,host=$IOMMU_GPU_AUDIO \
    -device vfio-pci,host=$IOMMU_USB \
    -usb -device usb-kbd -device usb-tablet \
    -device nec-usb-xhci,id=xhci \
    -netdev user,id=net0 -device e1000-82545em,netdev=net0,id=net0,mac=52:54:00:c9:18:27 \
    -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
	  -drive if=pflash,format=raw,readonly,file=/home/yu/vm/OSX-KVM/OVMF_CODE.fd \
    -drive if=pflash,format=raw,file=/home/yu/vm/OSX-KVM/OVMF_VARS.fd \
	  -smbios type=2 \
    -device ide-drive,bus=ide.2,drive=Clover \
	  -drive id=Clover,if=none,snapshot=on,format=qcow2,file=$CLOVER \
	  -device ide-drive,bus=ide.1,drive=MacHDD \
	  -drive id=MacHDD,if=none,file=$IMG,format=raw \
    -device ide-drive,bus=ide.0,drive=MacDVD \
	  -drive id=MacDVD,if=none,snapshot=on,media=cdrom,file=$ISO > /dev/null 2>&1 &
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
