#!/bin/bash

# Check if the script is executed as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
# END Check if you are sudo

# Variables
VBIOS=/root/vBIOS.rom
NVFLASH=/root/nvflash_linux
videobusid="0000:06:00.0"
# END Variables

_start()
{
# Memory lock limit
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
}

_stop()
{
# Reload the kernel modules. This loads the drivers for the GPU
modprobe snd_hda_intel
sleep 5
modprobe nvidia_drm
sleep 2
modprobe nvidia_modeset
sleep 2
modprobe nvidia
sleep 5

# Re-Bind EFI-Framebuffer and Re-bind to virtual consoles
# [Source] [https://github.com/joeknock90/Single-GPU-Passthrough/blob/master/README.md#vm-stop-script]
echo 1 > /sys/class/vtconsole/vtcon0/bind
sleep 1
echo 1 > tee /sys/class/vtconsole/vtcon1/bind
sleep 5

# Reload the Display Manager to access X
systemctl start lightdm
sleep 5

echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind
sleep 1
}

extract_vbios()
{
  $NVFLASH --save $VBIOS
}

_start
extract_vbios
_stop
exit
