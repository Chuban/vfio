#!/bin/bash

## Check if the script is being run as root
[[ "$EUID" -ne 0 ]] && echo "Please run as root" && exit 1

## Tap interface
tap_interface(){
  tap_start(){
    if [[ ! $(ip tuntap list | grep $1) ]]; then
      ip tuntap add mode tap user $USER name $TAP_INTERFACE
      ip addr add dev $1 $TAP_IP
      ip link set dev $1 up
    fi
  }
  tap_stop(){
    if [[ $(ip tuntap list | grep $1) ]]; then
      ip link set dev $1 down
      ip tuntap del mode tap name $TAP_INTERFACE
    fi
  }
  if [ $1 == start ]; then tap_start $TAP_INTERFACE; elif [ $1 == stop ]; then tap_stop $TAP_INTERFACE; fi
}

## DHCP Server (DNSmasq)
dhcp_server(){
  dhcp_start(){
    [[ -f /var/run/dnsmasq.pid ]] || dnsmasq --conf-file=$DNSMASQ_CONF
  }
  dhcp_stop(){
    [[ -f /var/run/dnsmasq.pid ]] && sudo kill -15 $(cat /var/run/dnsmasq.pid) && sudo rm /var/run/dnsmasq.pid
  }
  if [ $1 == start ]; then dhcp_start; elif [ $1 == stop ]; then dhcp_stop; fi
}

## Samba server
samba_server(){
  samba_start(){
    [[ -f /var/run/smbd.pid ]] || sudo smbd --configfile=$SMB_CONF
  }
  samba_stop(){
    [[ -f /var/run/smbd.pid ]] && sudo kill -15 $(cat /var/run/smbd.pid)
  }
  if [ $1 == start ]; then samba_start; elif [ $1 == stop ]; then samba_stop; fi
}

## Load the config file
source "${BASH_SOURCE%/*}/config"

## Check libvirtd
[[ $(systemctl status libvirtd | grep running) ]] || systemctl start libvirtd && sleep 1 && LIBVIRTD=STOPPED

## Memory lock limit
[[ $ULIMIT != $ULIMIT_TARGET ]] && ulimit -l $ULIMIT_TARGET

## Kill the Display Manager
systemctl stop lightdm
sleep 1

## Remove the framebuffer and console
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

## Detach the GPU
virsh nodedev-detach $VIRSH_GPU > /dev/null 2>&1
virsh nodedev-detach $VIRSH_GPU_AUDIO > /dev/null 2>&1

## Load vfio
modprobe vfio-pci

## Start the network
tap_interface start
dhcp_server start
samba_server start

## QEMU (VM) command
qemu-system-x86_64 -runas $VM_USER -enable-kvm \
  -nographic -vga none -parallel none -serial none \
  -m $RAM \
  -cpu host,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_time,hv_vapic,hv_vendor_id=0xDEADBEEFFF \
  -rtc clock=host,base=localtime \
  -smp $CORES,sockets=1,cores=$(( $CORES / 2 )),threads=2 \
  -device vfio-pci,host=$IOMMU_GPU,multifunction=on,x-vga=on,romfile=$VBIOS \
  -device vfio-pci,host=$IOMMU_GPU_AUDIO \
  -device virtio-net-pci,netdev=net0 \
  -netdev tap,id=net0,ifname=$TAP_INTERFACE,script=no,downscript=no,vhost=on \
  -drive if=pflash,format=raw,readonly,file=$OVMF \
  -drive media=cdrom,file=$WINDOWS_ISO,id=cd1,if=none \
  -device ide-cd,bus=ide.1,drive=cd1 \
  -drive media=cdrom,file=$VIRTIO,id=cd2,if=none \
  -device ide-cd,bus=ide.1,drive=cd2 \
  -device virtio-scsi-pci,id=scsi0 \
  -device scsi-hd,bus=scsi0.0,drive=rootfs \
  -drive id=rootfs,file=$WINDOWS_IMG,media=disk,format=raw,if=none >> $LOG 2>&1 &

## Wait for QEMU
wait

## Stop the network
tap_interface stop
dhcp_server stop
samba_server stop

## Unload vfio module
modprobe -r vfio-pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

## Reattach the GPU
virsh nodedev-reattach $VIRSH_GPU_AUDIO > /dev/null 2>&1
virsh nodedev-reattach $VIRSH_GPU > /dev/null 2>&1

## Reload the framebuffer and console
echo 1 > /sys/class/vtconsole/vtcon0/bind
nvidia-xconfig --query-gpu-info > /dev/null 2>&1
echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/bind

## Reload the Display Manager
systemctl start lightdm

## If libvirtd was stopped then stop it
[[ $LIBVIRTD == "STOPPED" ]] && systemctl stop libvirtd

## Restore ulimit
ulimit -l $ULIMIT
