# Install guide for QEMU and VFIO
## ArchLinux
### Install the necessary packages
```
# pacman -S qemu ovmf
```

### Enabling IOMMU support on boot
For `systemd-boot`, edit `/boot/loader/entries/arch.conf` and add `intel_iommu=on` **OR** `amd_iommu=on` and `iommu=pt`.
```
# AMD
options root=/dev/sda2 amd_iommu=on iommu=pt
---------------------------------------------
# Intel
options root=/dev/sda2 intel_iommu=on iommu=pt
```
Reboot.
----
For `GRUB` edit `/etc/default/grub` and append your kernel options to the `GRUB_CMDLINE_LINUX_DEFAULT`.
```
# AMD
GRUB_CMDLINE_LINUX_DEFAULT="amd_iommu=on iommu=pt"
---------------------------------------------------
# Intel
GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on iommu=pt"
```
And then automatically re-generate the grub.cfg file with:
```
# grub-mkconfig -o /boot/grub/grub.cfg
```
Reboot.
----
After reboot IOMMU should be working
```
[yu@ryzen ~]$ dmesg | grep -e DMAR -e IOMMU
--------------------------------------------
[    0.492684] AMD-Vi: IOMMU performance counters supported
[    0.494370] AMD-Vi: Found IOMMU at 0000:00:00.2 cap 0x40
[    0.494644] perf/amd_iommu: Detected AMD IOMMU #0 (2 banks, 4 counters/bank).
```

That's everything; unlike two GPU passthrough you don't need to load kernel modules on boot.

## For more information refer to this guides
[ArchWiki QEMU](https://wiki.archlinux.org/index.php/QEMU)

[ArchWiki PCI passthrough via OVMF](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF)

[How to setup a gaming virtual machine with gpu passthrough qemu kvm libvirt and vfio](https://www.se7ensins.com/forums/threads/how-to-setup-a-gaming-virtual-machine-with-gpu-passthrough-qemu-kvm-libvirt-and-vfio.1371980/)
