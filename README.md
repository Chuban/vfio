# Single GPU passthrough

## Last Update
2018/12/30

## Table of Contents
1. [Start here](#start-here)
1. [What is this](#what-this-is)
1. [Wiki](#wiki)
1. [Branches](#branches)
1. [Known problems](#known-problems)
1. [TODO](#todo)

## Start here
- [How to use the script for Windows](https://gitlab.com/YuriAlek/vfio/wikis/Use/#windows).
- [How to use the script for MacOs](https://gitlab.com/YuriAlek/vfio/wikis/Use/#macos).
- [How to use the script for Linux](https://gitlab.com/YuriAlek/vfio/wikis/Use/#linux).

## What this is
A series of scripts that allows you to do GPU passthrough with only one GPU in the system by detaching the GPU from the host and passing it to the guest, usually a Windows VM.

However, you may not use this method as it is tedious and having two GPUs allows you to do things like dual monitors (one running Linux and the other running Windows) or [LookingGlass][8].

## Wiki
[Check the wiki for more information and guides on how to make it work](https://gitlab.com/YuriAlek/vfio/wikis/Home).

## Branches
I keep more than one branch for multiple purposes. [There is a personal branch][1] where I have my actual configuration; [a testing branch][2] where I push changes while I am testing new things, it is **NOT stable**; and [a testing-auto branch][3] where I **try** to make everything work automatically.

## Known problems
Audio is not supported, yet. I use an external USB DAC.

Performance is not important to me at this moment. There is a lot of things that you can do to get better performance.

MacOS High Sierra does not like USB hubs, therefore anything connected to a hub won't work. Mojave works fine with hubs.

Windows 10 Pro 1709 works for me, but 1803 does not (may be the UEFI). [I have read that the 1803 version comes with a Spectre patch and the performance is bad][4]. The Spectre patch can be disabled.

## TODO
- [ ] Audio.
- [ ] CPU pinning.
- [ ] Performance tunning for QEMU.
- [ ] [Automation][3]
- [ ] Don't kill X server, [shifter and xpra may be the solution][5]. Also [uswsusp (userspace software suspend)][6]. [Source][7]

<!-- Links -->
[1]: /tree/personal "Personal branch"
[2]: /tree/testing "Testing branch"
[3]: /tree/testing-auto "Testing-auto branch"
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
