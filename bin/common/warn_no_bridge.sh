#!/usr/bin/env bash

cat << EOF
Your default interface is not a host bridge.
When using the libvirt provider, you must set up a host bridge interface in order for the VM
to be accessible on the public IP from the KVM host.
If using wicked, you can put the following in /etc/sysconfig/network/ifcfg-${DEFAULT_IF}:
   BOOTPROTO='none'
   STARTMODE='auto'
   DHCLIENT_SET_DEFAULT_ROUTE='yes'
and the following in /etc/sysconfig/network/ifcfg-br0:
   DHCCLIENT_SET_DEFAULT_ROUTE='yes'
   STARTMODE='auto'
   BOOTPROTO='dhcp'
   BRIDGE='yes'
   BRIDGE_STP='off'
   BRIDGE_FORWARDDELAY='0'
   BRIDGE_PORTS='eth0'
   BRIDGE_PORTPRIORITIES='-'
   BRIDGE_PATHCOSTS='-'
then run \`wicked ifreload all\`, and try \`$COMMAND\` again
EOF
