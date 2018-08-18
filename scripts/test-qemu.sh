#!/bin/bash

# Check if the script is executed as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
# END Check if you are sudo

source config.sh

_start()
{
# Memory lock limit
if [ $(ulimit -a | grep "max locked memory" | awk '{print $6}') != 12884900 ]; then
  ulimit -l 12884900
fi

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
modprobe vfio
sleep 1
modprobe vfio_iommu_type1
sleep 1
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
}

_stop()
{
# Wait for QEMU to finish before continue
wait
sleep 5

# Unload the vfio module. I am lazy, this leaves the GPU without drivers
modprobe -r vfio-pci
sleep 2
modprobe -r vfio_iommu_type1
sleep 2
modprobe -r vfio
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

# Restore ulimit
ulimit -l $ULIMIT
}

_help()
{
  echo "Usage: test-qemu.sh [OPTIONS]"
  echo "  start"
  echo "  stop"
}

_do()
{
if [ "$1" = "start" ]; then
  _start
  exit
elif [ "$1" = "stop" ]; then
  _stop
  exit
else
  _help
  exit 1
fi
}

if [[ $1 ]]; then
  _do $1
else
  _help
  exit 1
fi
