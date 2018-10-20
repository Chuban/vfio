# Single GPU passthrough with QEMU and VFIO
<!-- AKA Passthrough VGA on first slot -->

![Windows 10 1709](/Screenshots/Windows 10 QEMU single GPU info.png)*Windows 10 1709*

## Table of Contents
1. [What this does](#what-this-does)
2. [What you need](#what-you-need)
3. [Submit your own configuration](#submit-your-own-configuration)
4. [My system](#my-system)
5. [vBIOS](#vbios)
6. [Configure](#configure)
7. [Known problems](#known-problems)
8. [TODO](#todo)

## Last Update
2018/10/20

## What this does
In one command it kills X, frees the GPU from drivers and console, detaches the GPU from the host, starts the VM with the GPU, waits until the VM is off, reattaches the GPU to the host and starts lightdm.

## What you need
* An IOMMU enabled motherboard. Check your motherboard manual for an option in BIOS to enable IOMMU.
* CPU support for AMD-v/VT-x and AMD-Vi/VT-d (AMD/Intel).
* Virtualization support enabled on BIOS. Check your motherboard manual if you need help.
* One GPU that supports UEFI and its BIOS. All GPUs from 2012 and later should support this, some may have issues. If the GPU does not support UEFI you may be able to make it work, but you won't see anything in the screen until the drivers inside Windows kick in.
* QEMU, OVMF UEFI and VIRTIO drivers for Windows. [If you need to install, refer to the Install guide](Install.md)
* [Optional] An hard drive only for Windows.
* [Recommended] Another computer to login remotely with `ssh` for convenience, at least until you have everything working.

## Submit your own configuration
[Create a pull merge](https://gitlab.com/YuriAlek/vfio/merge_requests/new) with [a file explaining how you got it working](Hardware configurations/README.md).

## My system
```
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
                                        Linux Kernel: 4.18.14
                                       Nvidia divers: 396.51-1
                                        QEMU version: 3.0.0-3
                                        OVMF version: r24601

                                                 [Guests]
                                           Windows 10 Pro 1709 x64
                                          MacOS High Sierra 10.13.3
```  

## vBIOS
I experienced some weird things when doing this on the display, like a corruption of the image, it may be my GPU. If you encounter anything, a reboot solved my problems.

### Method 1 - Linux
It did not work for me, the ROM is 59KiB and it should be around 162KiB. It may work for you.
1. Execute `scripts/iommu.sh` to get the BUS ID for the GPU. Looks like `0000:06:00.0`.
2. Edit `scripts/extract-vbios-linux.sh` to your convenience. Change `videobusid=`. [Optional] Change also the location where the vBIOS will be save `VBIOS=`.
3. Make the script executable with `chmod +x scripts/extract-vbios-linux.sh`.
4. Link the service to systemd: `ln -s scripts/qemu@.service /usr/lib/systemd/system/`.
5. Execute the systemd unit with `sudo systemctl start qemu@extract-vbios-linux.service`. You can also do it over `ssh`. The screen will turn dark for a while. The extracted ROM will be in the root directory `/root/vBIOS.rom`

From here you are alone, I don't know how to proceed. Maybe you need to edit, maybe don't.

### Method 2 - nvflash in Linux
1. Download nvflash https://www.techpowerup.com/download/nvidia-nvflash/. Do not install from AUR; the package it's broken.
2. Unzip it as `/root/nvflash_linux` with `# unzip nvflash_5.414.0_linux.zip -d /root/`.
3. Execute `scripts/iommu.sh` to get the BUS ID for the GPU. Looks like `0000:06:00.0`.
4. Edit `scripts/extract-vbios-nvflash.sh`. Change the variables `videobusid` with your GPU BUS ID; `NVFLASH` if you changed the location of the executable; and `VBIOS` if you want the ROM in other path.
5. Link the service to systemd: `ln -s scripts/qemu@.service /usr/lib/systemd/system/`.
6. Execute the systemd unit with `sudo systemctl start qemu@extract-vbios-nvflash.service`. You can also do it over `ssh`. The screen will turn dark for a while. The extracted ROM will be in the root directory `/root/vBIOS.rom`
7. [Edit the vBIOS](#edit-the-vbios)

### Method 3 - Windows
[Source](https://www.youtube.com/watch?v=1IP-h9IKof0). [You can download the bios from techpowerup.com](https://www.techpowerup.com/vgabios/); if you do so, [skip to edit the vBIOS](#edit-the-vbios).
1. [Download and install GPU-Z](https://www.techpowerup.com/gpuz/).
2. [Open GPU-Z and backup the GPU BIOS](/Screenshots/GPU-Z vBIOS.png). Right next to the `Bios Version`; in my case `80.04.C3.00.0F`, there is an icon for backup. A file named `GK104.rom` will be created [Your file name may vary].
3. [Edit the vBIOS](#edit-the-vbios)

### Edit the VBIOS
1. Open the vBIOS ROM (`vBIOS.rom`) in the HEX editor.
2. [After a bunch of `00`, there is a `55`, or `U` in HEX; delete everything before the `55`](Screenshots/Hex vBIOS.png), and save. I strongly recommend not to overwrite the original ROM. [Note that series of `FF` values have been reported on a GTX 1060](Screenshots/Hex vBIOS 1060.png)

## Configure
1. Clone this repository
```bash
$ git clone https://gitlab.com/YuriAlek/vfio.git
```

2. [Optional] [Download virtio drivers](https://pve.proxmox.com/wiki/Windows_VirtIO_Drivers). If you do not, modify `scripts/windows.sh`.
```
$ wget -o virtio-win.iso "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
```

4. Get the iommu groups needed for the VM (GPU, GPU audio and USB controller). They look like `06:00.0`
```
$ chmod +x scripts/iommu.sh
$ scripts/iommu.sh
-------------------------
# GPU
IOMMU group 13
	  06:00.0 VGA compatible controller [0300]: NVIDIA Corporation GK104 [GeForce GTX 770] [10de:1184] (rev a1)
	  06:00.1 Audio device [0403]: NVIDIA Corporation GK104 HDMI Audio Controller [10de:0e0a] (rev a1)
# USB 3.0 Controller
IOMMU group 16
	  07:00.3 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] USB 3.0 Host controller [1022:145f]
# SATA Controller
IOMMU group 18
	  08:00.2 SATA controller [0106]: Advanced Micro Devices, Inc. [AMD] FCH SATA Controller [AHCI mode] [1022:7901] (rev 51)
```

5. [Optional] Create the image for the VM. Only if not using a physical hard drive. You can edit the path, the size and the format. Check `man qemu-img` for more information.
```bash
$ qemu-img create -f raw /path/to/image/windows.raw 60G
```

6. Edit the config in `scripts/config.sh` to convenience. If you use systemd to start the VM you have to edit `EnvironmentFile` in `qemu@.service` to point to your config file. Variables you may have to edit:
   1. PCI devices. `IOMMU_GPU`; `IOMMU_USB`.
   2. User.
   3. Location of HDD/IMG, ISO, vBIOS and OVMF image.
   4. The Desktop Environment, Display Manager, Window Manager, etc. `lightdm`/`i3`.
   5. QEMU options like RAM and CPU cores.
   6. Kernel modules.
   7. Other things like add a command to kill PulseAudio `pulseaudio -k` and another, at the end of the script, to start it again `pulseaudio --start`.
   8. The network options `-device virtio-net-pci,netdev=n1 -netdev user,id=n1`.
   9. Swap virtio for sata as the HDD interface.

7. Start the VM
```
# scripts/windows-install.sh
```

8. When installing Windows, in the section `Where do you want to install Windows?` there will be no hard drives to install to; to fix it:
   1. Load driver
   2. Browse
   3. CD Drive (E:) virtio-win-0.1.1
   4. vioscsi
   5. w10
   6. amd64
   7. ok
   8. Load driver `Red Hat VirtIO SCSI pass-through controller (E:\vioscsi\w10\amd64\vioscsi.inf)`
   9. Next
   10. Select the `Unallocated Space`
   11. Proceed as normal.
   12. Let Windows find the drivers for the GPU (if Windows has network) or [download the updated ones from NVIDIA](https://www.nvidia.com/Download/index.aspx?lang=en-us).

9. Once installed Windows, run the VM with:
```
# scripts/windows.sh
```

### For the sake of convenience
```
# ln -s scripts/qemu@.service /usr/lib/systemd/system/
# ln -s scripts/qemu-mac@.service /usr/lib/systemd/system/
```
```bash
$ alias windows="sudo systemctl start qemu@windows.service"
$ alias macos="sudo systemctl start qemu-mac@macos-hs.service"
```
To start the Windows VM
```
$ windows
```
To start the MacOS VM
```
$ macos
```

### For MacOS
[Check this amazing guide for creating the MacOS install image and Clover](https://github.com/kholia/OSX-KVM).

## Known problems
### MacOS does not like USB hubs, therefore anything connected to a hub will be ignored.

### Windows version
Windows 10 Pro 1709 works for me, but 1803 does not (may be the UEFI). [I have heard that the 1803 version comes with a Spectre patch and the performance is bad](https://www.reddit.com/r/VFIO/comments/97unx4/passmark_lousy_2d_graphics_performance_on_windows/). The Spectre patch can be disabled.

## TODO
- [x] Unbind GPU without `virsh`.
- [x] Run QEMU as user.
- [x] Try if is necessary to edit `/etc/mkinitcpio.conf`. No need to load the kernel modules at boot.
- [x] Extract the vBIOS in Linux.
- [x] Install guide.
- [x] Fix the race condition.
- [ ] Network. [I am too lazy, check this](https://yurialek.gitlab.io/gitbook/docs/qemu/network.html). I will add it to the scripts at some point.
- [ ] Update macos script.
- [ ] IOMMU guide.
- [ ] Audio.
- [ ] Troubleshooting guide.
- [ ] How to edit the `windows.sh` script.
- [ ] Create scripts for install and use (Without DVD images).
- [ ] Improve the script with multiple options for HDD/IMG; network; PCI devices, etc.
- [ ] ACS Patch (Does not work for me).
- [ ] CPU pinning and RAM HugePages.
- [ ] Not kill X, [`shifter` & `xpra` may be the solution](https://www.linuxquestions.org/questions/linux-desktop-74/move-application-between-desktops-736982/#post4161705). Also [uswsusp (userspace software suspend)](https://wiki.archlinux.org/index.php/Uswsusp). [Source](https://www.reddit.com/r/linux_gaming/comments/98376e/i_am_creating_a_guide_for_gpu_passthrough_with/e4ebaoj/)

<!--
And you must supply QEMU with the Full GPU's ROM extracted extracted using a tool called "nvagetbios" , which you can find in a package called "envytools"
-->

<!-- Links -->
[Xen Wiki]: https://wiki.xen.org/wiki/VTd_HowTo
[IOMMU Hardware]:https://en.wikipedia.org/wiki/List_of_IOMMU-supporting_hardware
[archwiki-url]: https://wiki.archlinux.org/index.php/Main_page
[qemu_archwiki]: https://wiki.archlinux.org/index.php/QEMU
[kvm-archwiki]: https://wiki.archlinux.org/index.php/KVM
[pci_passthrough-archwiki]: https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF
[libvirt_archwiki]: https://wiki.archlinux.org/index.php/Libvirt
