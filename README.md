# Single GPU passthrough with QEMU and VFIO
<!-- AKA Passthrough VGA on first slot -->

![Windows 10 1709](/Screenshots/Windows 10 QEMU single GPU info.png)*Windows 10 1709*

## ToC
1. [What this does](#what-this-does)
2. [What you need](#what-you-need)
3. [My system](#my-system)
4. [Configure](#configure)
5. [About peripherals](#about-peripherals)
6. [Known problems](#known-problems)
7. [TODO](#todo)

## What this does
In one command it kills X, frees the GPU from drivers and console, detaches the GPU from the host, starts the VM with the GPU, waits until the VM is off, reattaches the GPU to the host and starts lightdm.

## What you need
* An IOMMU enabled motherboard. Check your motherboard manual.
* CPU support for AMD-v/VT-x and AMD-Vi/VT-d (AMD/Intel). And virtualization support enabled on BIOS.
* One GPU that supports UEFI and its BIOS. All GPUs from 2012 and later should support this.
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
      Linux Kernel: 4.17.11 vanilla
     Nvidia divers: 396.45-2
      QEMU version: 2.12.0-2
      OVMF version: r24021

               [Guests]
           Windows: Windows 10 Pro 1709 x64
             MacOS: MacOS 10.13.3

```  

## Configure
1. Clone this repository
```bash
git clone https://gitlab.com/YuriAlek/vfio.git
```

2. Enable vfio at boot. Edit `/etc/mkinitcpio.conf`
```
MODULES=(... vfio_pci vfio vfio_iommu_type1 vfio_virqfd ...)
HOOKS=(... modconf ...)
```

3. [Regenerate the initramfs](initramfs_archwiki)
```bash
sudo mkinitcpio -p linux
```

4. Reboot the system to load the vfio drivers

5. [Optional] [Download virtio drivers](virtio_drivers)
```
wget -o virtio-win.iso "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
```

6. Get the GPU BIOS [Source](GPU_BIOS_video)
<!-- [Why?][] -->

  [You can download the bios.](techpowerup vgabios) If you do so, download a HEX editor and skip to step 4.
  1. Boot the host into Windows.
  2. [Download and install GPU-Z](GPU-Z).
  3. [Download and install a HEX editor](bless).
  3. Open GPU-Z and backup the GPU BIOS. Right next to the `Bios Version`; in my case `80.04.C3.00.0F`, there is an icon for backup. A file named `GK104.rom` will be created. [There is also a way of doing it in Linux]() but it did not work for me.
  4. Open the ROM (`GK104.rom`) in the HEX editor.
  5. After a bunch of `00` there is a `55` or `U` in HEX, delete everything before the `55`, and save. I strongly recommend not to overwrite the original ROM.

And you must supply QEMU with the Full GPU's ROM extracted extracted using a tool called "nvagetbios" , which you can find in a package called "envytools"



<!-- \\ Mod this section, refer to guide -->
7. Get the iommu groups needed for the VM (GPU, GPU audio and USB controller)
```bash
chmod +x scripts/iommu.sh
bash scripts/iommu.sh
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

8. [Optional] Create the image for the VM. Only if not using a physical hard drive.
```
qemu-img create -f raw windows.raw 60G
```

9. Edit the script `windows-install.sh` and `windows.sh` to convenience. Things you may have to edit:
  1. PCI devices
  2. User
  3. Location of HDD, ISO, vBIOS and OVMF image
  4. The Desktop Environment, Display Manager, Window Manager, etc.
  5. QEMU options like RAM and CPU
  6. Kernel modules
<!--
Check the guides [IOMMU][], [other guide, may be important][]
-->
10. Start the VM
```
sudo scripts/windows-install.sh
```

11. When installing Windows, in the section `Where do you want to install Windows?` there will be no hard drives to install to; to fix it:
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
  12. Let Windows find the drivers for the GPU (if Windows has network) or [download the updated ones from NVIDIA](GPU_drivers).

12. Once installed Windows, run the VM with
```
sudo scripts/windows.sh
```

### For the sake of convenience
```bash
sudo ln -s scripts/qemu@.service /usr/lib/systemd/system/
```
```bash
alias windows="sudo systemctl start qemu@windows.service"
alias macos="sudo systemctl start qemu@macos-hs.service"
```
To start the Windows VM
```
windows
```
To start the MacOS VM
```
macos
```

## About peripherals
For audio I use an USB sound card.

For internet I use network.sh

For USB I simply passthrough an USB 3.0 controller.

## Known problems
### Race condition
There is something somewhere that makes it crash. That's why there is so many `sleep`

### Root
QEMU should never be run as root. If you must launch it in a script as root, you should use the `-runas` option to make QEMU drop root privileges.

### MacOS does not like USB hubs, therefore anything connected to a hub will be ignored by MacOS


## TODO
- [x] Unbind GPU without `virsh`
- [ ] Update macos script
- [ ] Network
- [ ] Audio
- [ ] IOMMU
- [ ] Troubleshooting
- [ ] Extract the vBIOS in Linux
- [ ] De-configure `/etc/mkinitcpio.conf`
- [ ] How to edit the `windows.sh` script
- [ ] Fix the race condition
- [ ] Create scripts for install and use (Without DVD images)
- [ ] Try to run the VM as user
- [ ] ???

<!-- Links -->
[techpowerup vgabios]: https://www.techpowerup.com/vgabios/
[GPU_BIOS_video]: https://www.youtube.com/watch?v=1IP-h9IKof0
[GPU-Z]: https://www.techpowerup.com/gpuz/
[bless]: https://github.com/bwrsandman/Bless
[Xen Wiki]: https://wiki.xen.org/wiki/VTd_HowTo
[IOMMU Hardware]:https://en.wikipedia.org/wiki/List_of_IOMMU-supporting_hardware
[archwiki-url]: https://wiki.archlinux.org/index.php/Main_page
[qemu_archwiki]: https://wiki.archlinux.org/index.php/QEMU
[kvm-archwiki]: https://wiki.archlinux.org/index.php/KVM
[pci_passthrough-archwiki]: https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF
[initramfs_archwiki]: https://wiki.archlinux.org/index.php/Mkinitcpio#Image_creation_and_activation
[virtio_drivers]: https://pve.proxmox.com/wiki/Windows_VirtIO_Drivers
[libvirt_archwiki]: https://wiki.archlinux.org/index.php/Libvirt
[GPU_drivers]: https://www.nvidia.com/Download/index.aspx?lang=en-us
[windows 10 screenshot]: /Screenshots/Windows 10 QEMU single GPU info.png
[macos screenshot]: /Screenshots/MacOS High Sierra 10.13.3 single GPU info.png
