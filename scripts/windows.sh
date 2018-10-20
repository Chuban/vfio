#!/bin/bash

# Check if the script is executed as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
# END Check if you are sudo

source config

# Memory lock limit.
if [ $(ulimit -a | grep "max locked memory" | awk '{print $6}') != $(( $(echo $RAM | tr -d 'G')*1048576+10 )) ]; then
  ulimit -l $(( $(echo $RAM | tr -d 'G')*1048576+10 ))
fi

## Kill X and related
systemctl stop lightdm > /dev/null 2>&1
killall i3 > /dev/null 2>&1
sleep 2

# Kill the console to free the GPU
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

# Unload the Kernel Modules that use the GPU
modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r nvidia
modprobe -r snd_hda_intel

# Load the kernel module
modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio-pci

# Detach the GPU from drivers and attach to vfio. Also the usb.
echo $videoid > /sys/bus/pci/drivers/vfio-pci/new_id
echo $videobusid > /sys/bus/pci/devices/$videobusid/driver/unbind
echo $videobusid > /sys/bus/pci/drivers/vfio-pci/bind
echo $videoid > /sys/bus/pci/drivers/vfio-pci/remove_id

echo $audioid > /sys/bus/pci/drivers/vfio-pci/new_id
echo $audiobusid > /sys/bus/pci/devices/$audiobusid/driver/unbind
echo $audiobusid > /sys/bus/pci/drivers/vfio-pci/bind
echo $audioid > /sys/bus/pci/drivers/vfio-pci/remove_id

echo $usbid > /sys/bus/pci/drivers/vfio-pci/new_id
echo $usbbusid > /sys/bus/pci/devices/$usbbusid/driver/unbind
echo $usbbusid > /sys/bus/pci/drivers/vfio-pci/bind
echo $usbid > /sys/bus/pci/drivers/vfio-pci/remove_id

# QEMU (VM) command
qemu-system-x86_64 -runas $USER -enable-kvm \
    -nographic -vga none -parallel none -serial none \
    -enable-kvm \
    -m $RAM \
    -cpu host,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_time,hv_vapic,hv_vendor_id=0xDEADBEEFFF \
    -rtc clock=host,base=localtime \
    -smp $CORES,sockets=1,cores=$CORES,threads=0 \
    -device vfio-pci,host=$IOMMU_GPU,multifunction=on,x-vga=on,romfile=$VBIOS \
    -device vfio-pci,host=$IOMMU_GPU_AUDIO \
    -device vfio-pci,host=$IOMMU_USB \
    -device virtio-net-pci,netdev=n1 \
    -netdev user,id=n1 \
    -drive if=pflash,format=raw,readonly,file=$OVMF \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-hd,bus=scsi0.0,drive=rootfs \
    -drive id=rootfs,file=$HDD,media=disk,format=raw,if=none > /dev/null 2>&1 &
# END QEMU (VM) command

# Wait for QEMU to finish before continue
wait
sleep 1

# Unload the vfio module. I am lazy, this leaves the GPU without drivers
modprobe -r vfio-pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

# Reload the kernel modules. This loads the drivers for the GPU
modprobe snd_hda_intel
modprobe nvidia_drm
modprobe nvidia_modeset
modprobe nvidia

# Bind the usb
#echo $usbid > /sys/bus/pci/drivers/xhci_hcd/new_id
echo $usbbusid > /sys/bus/pci/devices/$usbbusid/driver/unbind
echo $usbbusid > /sys/bus/pci/drivers/xhci_hcd/bind
#echo $usbid > /sys/bus/pci/drivers/xhci_hcd/remove_id
#ls -la /sys/bus/pci/devices/$usbbusid/

# Re-Bind EFI-Framebuffer and Re-bind to virtual consoles
# [Source] [https://github.com/joeknock90/Single-GPU-Passthrough/blob/master/README.md#vm-stop-script]
echo 1 > /sys/class/vtconsole/vtcon0/bind
sleep 1
echo 1 > tee /sys/class/vtconsole/vtcon1/bind
sleep 1

# Reload the Display Manager to access X
systemctl start lightdm
sleep 2

# Restore the Frame Buffer
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind
sleep 1

# Restore ulimit
ulimit -l $ULIMIT
