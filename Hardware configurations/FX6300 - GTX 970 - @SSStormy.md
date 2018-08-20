# System
```
                                                 [Author]
                                                 @SSStormy (GitHub & GitLab)

                                                [Hardware]
                                                 CPU: AMD FX6300
                                         Motherboard: ASUS M5A97 EVO R2.0
                                    Motherboard BIOS: 2603
                                                 RAM: 16GB
                                                 GPU: Gigabyte Nvidia GeForce GTX 970
                                           GPU model: GV-N970G1 GAMING-4GD
                                            GPU BIOS: 84.04.2f.00.80
                                        GPU codename: GM204

                                                [Software]
                                        Linux Distro: Arch Linux
                                        Linux Kernel: 4.18.1-arch1-1-ARCH
                                       Nvidia divers: 396.51
                                        QEMU version: 2.12.1-1
                                        OVMF version: NONE

                                                 [Guests]
                                          Windows 10 Pro 1709 x64
```

# The final script
You can find it [here](https://github.com/SSStormy/dotfiles/blob/master/scripts/windows.sh) among my dotfiles.

# How I did it

## vBIOS
I used Method 3.

Dumped it via GPU-Z and then used `bless` in Arch to edit it. The header was there and I removed it with no issues.

## Script will not work if run from within a DM/WM/X11
I could not get the script to work when running it from my WM (i3). lightdm was stopped, X11 and i3 were nowhere to be seen but the GPU was not properly detached. On screen I saw a black terminal with a blinking cursor. I could switch between TTYs.

The solution is to switch to a TTY (ctrl+shift+f2/f3 etc) and run the script from there.

## "module nvidia is in use"
This occured during the initial module unloading stage. The nvidia module wasn't being unloaded.

The solution was to unload the `nvidia_uvm` module: Add
```
modprobe -r nvidia_uvm
```
Next to `modprobe -r nvidia_drm`

From testing it appears that you don't have to load it manually since `modprobe nvidia` does the job, but just in case: To load it back up, add:
```
modprobe nvidia_uvm
```
Next to `modprobe nvidia_drm`

## Cannot boot off of ANY drives with OVMF
During testing where I didn't passthrough any PCI devices, the VM failed to boot off of any drive/iso/CD I gave to it. This only occured when I booted QEMU with the OVMF UEFI. I tested the `ovmf-git` and `edk2-ovmf` (AUR) but nothing had changed. 

The solution was to not use OVMF: Remove
```
-drive if=pflash,format=raw,readonly,file=$OVMF_CODE \
```
Doing this still allowed me to passthrough PCI devices.

## Incredibly slow drive speeds
During testing I had experienced some horrible drive speeds. Booting into the OVMF UEFI bios took well over a minute.

The solution was to tell QEMU to run the VM as a q35 machine: Add
```
-machine q35 \
```
Next to `-enable-kvm \`

## QCOW2
I used QCOW2 to create my drive image:
```
qemu-img create -f qcow2 windows.qcow2 200G
```

This is how I passed it onto QEMU:
```
-drive file=/home/$USER/vm/drive/windows.qcow2,if=virtio,format=qcow2 \
```

[Here](https://gist.github.com/shamil/62935d9b456a6f9877b5) is a guide on how to mount QCOW2 as if it were an ISO/block on the host.

## QCOW2 Drive does not show up during windows install
Installing the vioscsi drivers did not help either.

The solution was to install the viostar amd64 driver. Then the drive showed up perfectly fine and worked for all further startups.

## No network
After installing windows and booting into it, windows could not establish a ethernet connection.

The solution was to remove these from the QEMU launch arguments:
```
-device virtio-net-pci,netdev=n1 \
-netdev user,id=n1 \
```

## Passing through USB devices via -object input-linux
For my peripherals (mouse/kb) I passed this to the QEMU arguments:
```
-object input-linux,id=kbd,evdev=/dev/input/by-id/usb-CM_Storm_Keyboard_--_QuickFire_XT-event-if01,grab_all=on,repeat=on \
-object input-linux,id=kbd2,evdev=/dev/input/by-id/usb-CM_Storm_Keyboard_--_QuickFire_XT-event-kbd,grab_all=on,repeat=on \
-object input-linux,id=mouse,evdev=/dev/input/by-id/usb-Logitech_USB_Optical_Mouse-event-mouse
```

## No audio I/O
After install, windows could not detect my sound card.

The solution was to pass it through to the VM:

Config:
```
IOMMU_PCI_AUDIO=00:14.2
pciaudioid="1002 4383"
pciaudiobusid="0000:00:14.2"
```

During detachment, below the GPU audio:
```
echo $pciaudioid > /sys/bus/pci/drivers/vfio-pci/new_id
echo $pciaudiobusid > /sys/bus/pci/devices/$pciaudiobusid/driver/unbind
echo $pciaudiobusid > /sys/bus/pci/drivers/vfio-pci/bind
echo $pciaudioid > /sys/bus/pci/drivers/vfio-pci/remove_id
```

In the QEMU arguments, below IOMMU_GPU:
```
-device vfio-pci,host=$IOMMU_PCI_AUDIO \
```

During reattachment, below nvidia modprobes:
```
echo $pciaudioid > /sys/bus/pci/drivers/snd_hda_intel/new_id
echo $pciaudiobusid > /sys/bus/pci/devices/$pciaudiobusid/driver/unbind
echo $pciaudiobusid > /sys/bus/pci/drivers/snd_hda_intel/bind
```

`$ /dev/input/by-id/usb*` will let you see what peripherals you can passthrough this way.

## The sleep calls
I got rid of most of the `sleep` calls and the script still worked.

## Misc: Monitor stdio
I added `-monitor stdio \` to the QEMU paramaters to be able to launch the script via TMUX, then in windows SSH into the host machine and attach to the TMUX session. This allows me to run QEMU commands from within the VM.
