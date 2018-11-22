#!/bin/bash
## Edit this comand before using it
## Required software
##   DNSmasq
##   samba
##   iproute2
##   qemu
##   ovmf
## Maybe I am missing something else

## For fucking Windows to be able to install stuff on a network drive
## https://community.spiceworks.com/topic/366976-trying-to-install-a-program-to-a-network-drive
## All you need to do is run Registry Editor (regedit.exe), locate the key
## HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Windows/CurrentVersion/Policies/System, and create a new DWORD entry with the name
## EnableLinkedConnections and value 1:

## Check if the script is being run as root
[[ "$EUID" -ne 0 ]] && echo "Please run as root" && exit 1

## Load the config file.
source config-macos

## Memory lock limit.
## By default, at least in Arch, a user can not lock so much memory, so you have to allow it plus 10 just to be sure.
## The `+100000` is just because it ay use a little shade over 12G and that is 100M
## If you get an error that QEMU can't allocate memory just do `ulimit -l unlimited` as root. Revert it after you shutdown the VM.
if [ $(ulimit -a | grep "max locked memory" | awk '{print $6}') != $(( $(echo $RAM | tr -d 'G')*1048576+100000 )) ]; then
  ulimit -l $(( $(echo $RAM | tr -d 'G')*1048576+100000 ))
fi

## Kill X and related. You can change `lightdm` and `i3` for whatever you use.
## Make shure you don't have anything important open because this will kill the X session.
## You can also just do "killall xorg" or "killall xinit"
systemctl stop lightdm > /dev/null 2>&1
killall i3 > /dev/null 2>&1
# killall xorg
# killall xinit
sleep 2

## START ## Network stuff
## THIS REQUIRES A FIREWALL BACKEND LIKE IPTABLES. If there is nothing routing the traffic this will be useless.
## Also open ports 53 tcp/udp 67,68 tcp/udp and icmp in ther firewall rules for the $TAP_INTERFACE
tap_interface(){
  tap_stop(){
    if [[ $(ip tuntap list | grep $1) ]]
    then
      sudo ip link set dev $1 down
      sudo ip tuntap del mode tap name tap0
    fi
  }
  tap_start(){
    if [[ ! $(ip tuntap list | grep $1) ]]
    then
      #sudo tunctl -u $VM_USER
      sudo ip tuntap add mode tap user $USER name tap0
      sudo ip addr add dev $1 10.10.10.1/24
      sudo ip link set dev $1 up
    fi
  }
  if [ $1 == start ]
  then
    tap_start $TAP_INTERFACE
  elif [ $1 == stop ]
  then
    tap_stop $TAP_INTERFACE
  fi
}

dhcp_server(){
  dhcp_stop(){
    [[ -f /var/run/dnsmasq.pid ]] && sudo kill -15 $(cat /var/run/dnsmasq.pid) && sudo rm /var/run/dnsmasq.pid
  }
  dhcp_start(){
    [[ -f /var/run/dnsmasq.pid ]] || dnsmasq --conf-file=$DNSMASQ_CONF
  }
  if [ $1 == start ]
  then
    dhcp_start
  elif [ $1 == stop ]
  then
    dhcp_stop
  fi
}

## Samba server controls
samba_server(){
  samba_stop(){
    [[ -f /var/run/smbd.pid ]] && echo "Stopping samba" && sudo kill -15 $(cat /var/run/smbd.pid) || echo "Samba was already stopped"
  }
  samba_start(){
    [[ -f /var/run/smbd.pid ]] && echo "Samba was already started" || echo "Starting samba" && sudo smbd --configfile=$SMB_CONF
  }
  if [ $1 == start ]
  then
    samba_start
  elif [ $1 == stop ]
  then
    samba_stop
  fi
}

## Start the network
tap_interface start
dhcp_server start
samba_server start

## For samba to work you must run as root `smbpasswd -a <USER>`

## END ## Network stuff


## Kill the console to free the GPU.
## The console, by default, is attached to the boot GPU, in this case there is only one and we need to left it unused to remove it from the system.
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

## Unload the Kernel Modules that use the GPU
## You may need to unload more or other kernel modules (drivers) for your specific GPU.
## This command allows you to see which modules depend uppon others. Change nvidia for noveau if you are using the OSS drivers or for the AMD equivalent.
# lsmod | grep nvidia
## The left column are the modules and the right are the modules that are using that module. The modules should be unloaded only if there is no other modules using it; if there are, then unload them first.
# nvidia_drm             49152  7
# nvidia_modeset       1044480  23 nvidia_drm
# nvidia              16605184  1038 nvidia_modeset
modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r nvidia
## Also unload the audio modules, may be more than one, because they use the audio device in the GPU
modprobe -r snd_hda_intel

## Load the kernel module related to vfio
modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio-pci

## Detach the GPU from drivers and attach to vfio. Also the usb.
## This may not be the right way, but it works for me and there is no symptoms of anything not working.
echo $videoid > /sys/bus/pci/drivers/vfio-pci/new_id
echo $videobusid > /sys/bus/pci/devices/$videobusid/driver/unbind
echo $videobusid > /sys/bus/pci/drivers/vfio-pci/bind
echo $videoid > /sys/bus/pci/drivers/vfio-pci/remove_id

echo $audioid > /sys/bus/pci/drivers/vfio-pci/new_id
echo $audiobusid > /sys/bus/pci/devices/$audiobusid/driver/unbind
echo $audiobusid > /sys/bus/pci/drivers/vfio-pci/bind
echo $audioid > /sys/bus/pci/drivers/vfio-pci/remove_id

echo $usbid > /sys/bus/pci/drivers/vfio-pci/new_id
echo $usbbusid > /sys/bus/pci/devices/$usbbusid/driver/unbind
echo $usbbusid > /sys/bus/pci/drivers/vfio-pci/bind
echo $usbid > /sys/bus/pci/drivers/vfio-pci/remove_id

## QEMU (VM) command
#qemu-system-x86_64 -runas $USER -enable-kvm \
#    -nographic -vga none -parallel none -serial none \
#    -m $RAM \
#    -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,$MY_OPTIONS\
#    -machine pc-q35-2.9 \
#    -smp $CORES,cores=$CORES \
#    -device vfio-pci,host=$IOMMU_GPU,multifunction=on,x-vga=on,romfile=$VBIOS \
#    -device vfio-pci,host=$IOMMU_GPU_AUDIO \
#    -device vfio-pci,host=$IOMMU_USB \
#    -usb -device usb-kbd -device usb-tablet \
#    -device nec-usb-xhci,id=xhci \
#    -device virtio-net-pci,netdev=net0 \
#    -netdev tap,id=net0,ifname=$TAP_INTERFACE,script=no,downscript=no,vhost=on \
#    -device #isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerI#nc" \
#	  -drive if=pflash,format=raw,readonly,file=$OVMF \
#    -drive if=pflash,format=raw,file=$OVMF_VARS \
#	  -smbios type=2 \
#    -device ide-drive,bus=ide.2,drive=Clover \
#	  -drive id=Clover,if=none,snapshot=on,format=qcow2,file=$CLOVER \
#	  -device ide-drive,bus=ide.1,drive=MacHDD \
#	  -drive id=MacHDD,if=none,file=$IMG,format=raw > /dev/null 2>&1 &


qemu-system-x86_64 -runas $USER -enable-kvm \
  -nographic -vga none -parallel none -serial none \
  -m $RAM \
  -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,$MOJAVE_OPTIONS\
  -machine pc-q35-2.11 \
  -smp $CORES,sockets=1,cores=$(($CORES/2)),threads=2 \
  -device vfio-pci,host=$IOMMU_GPU,multifunction=on,x-vga=on,romfile=$VBIOS \
  -device vfio-pci,host=$IOMMU_GPU_AUDIO \
  -device vfio-pci,host=$IOMMU_USB \
  -usb -device usb-kbd -device usb-tablet \
  -device nec-usb-xhci,id=xhci \
  -netdev tap,id=net0,ifname=$TAP_INTERFACE,script=no,downscript=no \
  -device e1000-82545em,netdev=net0,id=net0,mac=52:54:00:c9:18:27 \
  -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
  -drive if=pflash,format=raw,readonly,file=$OVMF \
  -drive if=pflash,format=raw,file=$OVMF_VARS \
  -smbios type=2 \
  -device ide-drive,bus=ide.2,drive=Clover \
  -drive id=Clover,if=none,snapshot=on,format=qcow2,file=$CLOVER_MOJAVE \
  -device ide-drive,bus=ide.1,drive=MacHDD \
  -drive id=MacHDD,if=none,file=$IMG_MOJAVE,format=raw,id=disk > /dev/null 2>&1 &

## Network
## virtio-net-pci does not work, obviously
## e1000 does not work
## rtl8139 does not work
## e1000-82545em 

## Wait for QEMU to finish before continuing
wait
sleep 1

## Stop the network
tap_interface stop
dhcp_server stop
samba_server stop

## Unload the vfio module. This leaves the GPU without drivers.
modprobe -r vfio-pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

## Reload the kernel modules that previously were unloaded. Load them inversed as you unloaded. The las unloaded should be the first to be loaded and viceversa. THIS MAY NOT BE THE CASE FOR YOU. This SHOULD load the drivers for the GPU.
modprobe snd_hda_intel
modprobe nvidia_drm
modprobe nvidia_modeset
modprobe nvidia

## Bind the USB. If you passed the USB controller to the VM.
#echo $usbid > /sys/bus/pci/drivers/xhci_hcd/new_id
## This does not exist, so...
#echo $usbbusid > /sys/bus/pci/devices/$usbbusid/driver/unbind
echo $usbbusid > /sys/bus/pci/drivers/xhci_hcd/bind
#echo $usbid > /sys/bus/pci/drivers/xhci_hcd/remove_id
#ls -la /sys/bus/pci/devices/$usbbusid/

## Rebind the EFI-Framebuffer and Rebind to virtual consoles
## [Source] [https://github.com/joeknock90/Single-GPU-Passthrough/blob/master/README.md#vm-stop-script]
echo 1 > /sys/class/vtconsole/vtcon0/bind
sleep 1
## This just creates a file called `tee`
#echo 1 > tee /sys/class/vtconsole/vtcon1/bind
sleep 1

## Reload the Display Manager to access X. You can also run startx, though I don't know how to do it and `startx` will probably not work.
systemctl start lightdm
sleep 2

## Restore the Frame Buffer.
## I tried MANY different ways and timings of doing this, and this is the only one that works, FOR ME.
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind
sleep 1

## Restore ulimit to the previous state.
ulimit -l $ULIMIT
