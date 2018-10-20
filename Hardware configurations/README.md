# A compilation of hardware and software combinations working for other people

**Before creating a merge pull, be sure to read this guide**

The files should be named like [{CPU} - {GPU} - {User}.md]; example
```
Ryzen 5 2600 - GTX 770 - @YuriAlek.md
```

## Inside must be something like this:
### System
```
                                                 [Author]
                                                 @YuriAlek

                                                [Hardware]
                                                 CPU: AMD Ryzen 5 2600
                                         Motherboard: Gigabyte AB350M-Gaming 3 rev1.1
                                    Motherboard BIOS: F23d
                                                 RAM: 16GB
                                                 GPU: Gigabyte Nvidia GeForce GTX 770
                                           GPU model: GV-N770OC-2GD
                                            GPU BIOS: 80.04.C3.00.0F
                                        GPU codename: GK104

                                                [Software]
                                        Linux Distro: ArchLinux
                                        Linux Kernel: 4.17.14 vanilla
                                       Nvidia divers: 396.51-1
                                        QEMU version: 2.12.1-1
                                        OVMF version: r24021

                                                 [Guests]
                                          Windows 10 Pro 1709 x64
                                         MacOS High Sierra 10.13.3
```

### How I did it
For extracting the `vBIOS` I used the 1st method in Linux and edited it.

You can add anything that you consider useful like the steps needed in your distro for installing everything or a link to your script. The more information, and solutions, the better.

### Files to modify
#### `scripts/windows.sh`
My GPU uses one more Kernel Module so I have to add it as the first module to unload and the last to load:
```
# Unload the Kernel Modules that use the GPU
modprobe -r nvidia_drm
sleep 1
...
------------------------
# Reload the kernel modules. This loads the drivers for the GPU
...
modprobe nvidia_drm
sleep 1
```

I use PulseAudio so I had to kill it for detaching the GPU.
```
## Kill X and related
pulseaudio -k
---------------------
# Reload the Display Manager to access X
...
pulseaudio --start
```

I don't pass a USB controller so I had to add manually USB devices.
```
# Remove
...
echo $usbid > /sys/bus/pci/drivers/vfio-pci/new_id
sleep 1
echo $usbbusid > /sys/bus/pci/devices/$usbbusid/driver/unbind
sleep 1
echo $usbbusid > /sys/bus/pci/drivers/vfio-pci/bind
sleep 1
echo $usbid > /sys/bus/pci/drivers/vfio-pci/remove_id
#ls -la /sys/bus/pci/devices/$usbbusid/
sleep 1
...
-device vfio-pci,host=$IOMMU_USB \
...
echo $usbbusid > /sys/bus/pci/devices/$usbbusid/driver/unbind
echo $usbbusid > /sys/bus/pci/drivers/xhci_hcd/bind
sleep 10
...
----------------------
# Add to the QEMU script
...
    -object input-linux,id=kbd,evdev=/dev/input/by-id/usb-HOLDCHIP_USB_Gaming_Keyboard-event-kbd,grab_all=on,repeat=on \
    -object input-linux,id=kbd2,evdev=/dev/input/by-id/usb-HOLDCHIP_USB_Gaming_Keyboard-if01-event-kbd,grab_all=on,repeat=on \
    -object input-linux,id=mouse-event,evdev=/dev/input/by-id/usb-Logitech_G700_Laser_Mouse_6B5EFC4B0035-event-mouse \
    -object input-linux,id=kbd3,evdev=/dev/input/by-id/usb-Logitech_G700_Laser_Mouse_6B5EFC4B0035-if01-event-kbd,grab_all=on,repeat=on \
...
```

I use an image instead of a hard drive.
```
# Remove
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-hd,bus=scsi0.0,drive=rootfs \
    -drive id=rootfs,file=$HDD,media=disk,format=raw,if=none
-----------------
# Add
	  -device ide-drive,bus=ide.1,drive=rootfs \
	  -drive id=rootfs,if=none,file=$IMG,format=raw
```
