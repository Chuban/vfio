# Single GPU passthrough

## Last Update
2019/03/22

## Table of Contents
- [Start here](#start-here)
- [What is this](#what-this-is)
- [Wiki](#wiki)
- [Branches](#branches)
- [Known problems](#known-problems)
- [TODO](#todo)

## Start here
- [How to use the script for Windows VMs](https://gitlab.com/YuriAlek/vfio/wikis/Use/#windows).
- [How to use the script for MacOS VMs](https://gitlab.com/YuriAlek/vfio/wikis/Use/#macos).
- [How to use the script for Linux VMs](https://gitlab.com/YuriAlek/vfio/wikis/Use/#linux).

## What this is
A series of scripts that allows you to do GPU passthrough with only one GPU in the system by detaching the GPU from the host and passing it to the guest, usually a Windows VM.

However, you may not use this method as it is tedious and having two GPUs allows you to do things like dual monitors (one running Linux and the other running Windows) or [LookingGlass][8].

## Wiki
[Check the wiki for more information and guides on how to make everything work](https://gitlab.com/YuriAlek/vfio/wikis/Home).

## Branches
I keep more than one branch for multiple purposes. [There is a personal branch][1] where I have my actual configuration; [a testing branch][2] where I push changes while I am testing new things, it is **NOT stable**; and [a testing-auto branch][3] where I **try** to make everything work automatically.

## Known problems
Audio is not configured on this guide, yet. I use an external USB DAC.

MacOS High Sierra does not like USB hubs, therefore anything connected to a hub won't work. Mojave works fine with hubs.

Windows 10 Pro 1709 works for me, but 1803 does not (may be the UEFI). [I have read that the 1803 version comes with a Spectre patch and the performance is bad][4]. The Spectre patch can be disabled.

`windows-basic.sh` and `windows-virsh.sh` reports no connection but it works (except pings).

## TODO
- [ ] Audio.
- [ ] `smb.conf` and `dnsmasq.conf` using the `config` file.
- [ ] Find a way to restore the GPU without `nvidia-xconfig --query-gpu-info`.
- [ ] [Automation][3].
- [ ] Don't kill X server, [shifter and xpra may be the solution][5]. Also [uswsusp (userspace software suspend)][6]. [Source][7]

<!-- Links -->
[1]: https://gitlab.com/YuriAlek/vfio/tree/personal "Personal branch"
[2]: https://gitlab.com/YuriAlek/vfio/tree/testing "Testing branch"
[3]: https://gitlab.com/YuriAlek/vfio/tree/testing-auto "Testing-auto branch"
[4]: https://www.reddit.com/r/VFIO/comments/97unx4/passmark_lousy_2d_graphics_performance_on_windows/
[5]: https://www.linuxquestions.org/questions/linux-desktop-74/move-application-between-desktops-736982/#post4161705
[6]: https://wiki.archlinux.org/index.php/Uswsusp "uswsusp"
[7]: https://www.reddit.com/r/linux_gaming/comments/98376e/i_am_creating_a_guide_for_gpu_passthrough_with/e4ebaoj/
[8]: https://github.com/gnif/LookingGlass "LookingGlass"
[pull merge]: https://gitlab.com/YuriAlek/vfio/merge_requests/new "Create a pull merge"
[Xen Wiki]: https://wiki.xen.org/wiki/VTd_HowTo
[IOMMU Hardware]: https://en.wikipedia.org/wiki/List_of_IOMMU-supporting_hardware
[archwiki-url]: https://wiki.archlinux.org/index.php/Main_page
[qemu_archwiki]: https://wiki.archlinux.org/index.php/QEMU
[kvm-archwiki]: https://wiki.archlinux.org/index.php/KVM
[pci_passthrough-archwiki]: https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF
[libvirt_archwiki]: https://wiki.archlinux.org/index.php/Libvirt
