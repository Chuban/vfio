#!/bin/bash
# Requires iproute2, dnsmasq, and firewall [iptables, shorewall, ...]

# Check if the script is executed as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
# END Check if you are sudo

# Variables
NIC=qemubr0
IP=10.10.10.1/24

start_network()
{
  ip link add name $NIC type bridge
  ip link set $NIC up
  ip address add $IP dev $NIC
}

stop_network()
{
  ip link set $NIC down
  ip link delete $NIC type bridge
}

start_dnsmasq()
{
  systemctl start dnsmasq
}

stop_dnsmasq()
{
  systemctl stop dnsmasq
}

_help()
{
  echo "Usage: network.sh [OPTIONS]"
  echo "  start - start the network"
  echo "  stop  - stop the network"
}

_start()
{
if [ "$1" = "start" ]; then
  start_network
  start_dnsmasq
  exit
elif [ "$1" = "stop" ]; then
  stop_dnsmasq
  stop_network
  exit
else
  _help
  exit 1
fi
}

if [[ $1 ]]; then
  _start $1
else
  _help
  exit 1
fi
