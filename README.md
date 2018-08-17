# Single GPU passthrough with QEMU and VFIO
<!-- AKA Passthrough VGA on first slot -->

![Windows 10 1709](/Screenshots/Windows 10 QEMU single GPU info.png)*Windows 10 1709*

## Table of Contents
1. [What this does](#what-this-does)
2. [What you need](#what-you-need)
3. [My system](#my-system)
4. [Configure](#configure)
5. [Known problems](#known-problems)
6. [TODO](#todo)

## What this does
In one command it kills X, frees the GPU from drivers and console, detaches the GPU from the host, starts the VM with the GPU, waits until the VM is off, reattaches the GPU to the host and starts lightdm.

## What you need
* An IOMMU enabled motherboard. Check your motherboard manual.
* CPU support for AMD-v/VT-x and AMD-Vi/VT-d (AMD/Intel). And virtualization support enabled on BIOS.
* One GPU that supports UEFI and its BIOS. All GPUs from 2012 and later should support this. If the GPU does not support UEFI you may be able to make it work, but you wont see anything in the screen until the drivers inside Windows kick in.
* QEMU, OVMF UEFI and VIRTIO drivers for Windows.
* [Optional] HDD only for Windows

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
                                        Linux Kernel: 4.17.14 vanilla
                                       Nvidia divers: 396.51-1
                                        QEMU version: 2.12.1-1
                                        OVMF version: r24021

                                                 [Guests]
                                             Windows: Windows 10 Pro 1709 x64
                                               MacOS: MacOS High Sierra 10.13.3

```  

## Configure
1. Clone this repository
```bash
$ git clone https://gitlab.com/YuriAlek/vfio.git
```

2. [Optional] [Download virtio drivers](https://pve.proxmox.com/wiki/Windows_VirtIO_Drivers). If you do not, modify the `windows.sh` script.
```
$ wget -o virtio-win.iso "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
```

3. Get the GPU BIOS [Source](https://www.youtube.com/watch?v=1IP-h9IKof0). [You can download the bios from techpowerup.com](https://www.techpowerup.com/vgabios/); if you do so, download a HEX editor and skip to step 5.
  1. Boot the host into Windows.
  2. [Download and install GPU-Z](https://www.techpowerup.com/gpuz/).
  3. [Download and install a HEX editor](https://github.com/bwrsandman/Bless).
  4. [Open GPU-Z and backup the GPU BIOS](/Screenshots/vBIOS.png). Right next to the `Bios Version`; in my case `80.04.C3.00.0F`, there is an icon for backup. A file named `GK104.rom` will be created [Your file name may vary].
  5. Open the vBIOS ROM (`GK104.rom`) in the HEX editor.
  6. [After a bunch of `00` there is a `55` or `U` in HEX, delete everything before the `55`](/Screenshots/Hex vBIOS.png), and save. I strongly recommend not to overwrite the original ROM.

4. Get the iommu groups needed for the VM (GPU, GPU audio and USB controller)
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

5. [Optional] Create the image for the VM. Only if not using a physical hard drive.
```bash
$ qemu-img create -f raw windows.raw 60G
```

6. Edit the script `windows-install.sh` **and** `windows.sh` to convenience. Things you may have to edit:
  1. PCI devices
  2. User
  3. Location of HDD, ISO, vBIOS and OVMF image
  4. The Desktop Environment, Display Manager, Window Manager, etc.
  5. QEMU options like RAM and CPU
  6. Kernel modules

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
```
```bash
$ alias windows="sudo systemctl start qemu@windows.service"
$ alias macos="sudo systemctl start qemu@macos-hs.service"
```
To start the Windows VM
```
$ windows
```
To start the MacOS VM
```
$ macos
```

## Known problems
### Race condition
There is something somewhere that makes it crash. That's why there is so many `sleep`

### MacOS does not like USB hubs, therefore anything connected to a hub will be ignored by MacOS

### Sometimes works, sometimes does not
Sometimes the GPU will not have correct drivers, Windows may install them... or not.

Sometimes the QEMU command will just fail and the command continues and start X again.

Sometimes the QEMU command does not exit after shutting down the VM.

### Windows version
Windows 10 Pro 1709 works for me, but 1803 does not (may be the UEFI). I have heard that the 1803 version comes with a Spectre patch and the performance is pathetic.


## TODO
- [x] Unbind GPU without `virsh`
- [x] Update macos script
- [x] Try to run the VM as user.
- [x] Try if is necessary to edit `/etc/mkinitcpio.conf`
- [ ] Network
- [ ] Audio
- [ ] IOMMU guide
- [ ] Troubleshooting guide
- [ ] Extract the vBIOS in Linux guide
- [ ] How to edit the `windows.sh` script
- [ ] Fix the race condition
- [ ] Create scripts for install and use (Without DVD images)
- [ ] ACS Patch (Does not work for me)
- [ ] ???

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
