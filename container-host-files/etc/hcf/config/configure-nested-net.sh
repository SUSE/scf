#!/bin/bash

# This is a temporary workaround for UCP not giving us useful indexes between
# instances in the bosh spec.index style.

if test -z "${UCP_INSTANCE_ID}" ; then
    # This is not running on UCP; this is not needed
    exit 0
fi

target_subnet=$DIEGO_CELL_SUBNET

# converts from 255.255.255.0 to /24
mask2cdr ()
{
   # Assumes there's no "255." after a non-255 byte in the mask
   local x=${1##*255.}
   set -- 0^^^128^192^224^240^248^252^254^ $(( (${#1} - ${#x})*2 )) ${x%%.*}
   x=${1%%$3*}
   echo $(( $2 + (${#x}/4) ))
}

# converts from /16 to 255.255.0.0
cdr2mask ()
{
   # Number of args to shift, 255..255, first non-255 byte, zeroes
   set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
   [ $1 -gt 1 ] && shift $1 || shift
   echo ${1-0}.${2-0}.${3-0}.${4-0}
}

# converts an IP address to an int
ip2int()
{
    local a b c d
    { IFS=. read a b c d; } <<< $1
    echo $(((((((a << 8) | b) << 8) | c) << 8) | d))
}

# converts an int to an IP address
int2ip()
{
    local ui32=$1; shift
    local ip n
    for n in 1 2 3 4; do
        ip=$((ui32 & 0xff))${ip:+.}$ip
        ui32=$((ui32 >> 8))
    done
    echo $ip
}

# split the target subnet into the IP part and the mask number
# '127.20.0.0/16' to '127.20.0.0' and '16'
IFS='/' read -a subnet_parts <<< "$target_subnet"

target_ip_part="${subnet_parts[0]}"
target_subnet_part="${subnet_parts[1]}"

# get the pieces of the netmask for eth0
IFS=. read -r m1 m2 m3 m4 <<< `ifconfig eth0 | awk '/Mask:/{ print $4;} ' | awk -F':' '{print $2}'`
# get the pieces of the IP address for eth0
IFS=. read -r i1 i2 i3 i4 <<< `ifconfig eth0 | awk '/inet addr:/{ print $2;} ' | awk -F':' '{print $2}'`
# get the network address pieces of the target network
IFS=. read -r ti1 ti2 ti3 ti4 <<< $target_ip_part

# convert the netmask to a number so we can validate sizes
container_netmask_cidr=$(mask2cdr "${m1}.${m2}.${m3}.${m4}")

# Basically, we're saying that we can have 256 c-in-c networks, each with 256 addresses
if (( target_subnet_part > 16 )); then
  echo 1>&2 "Can't compute a 'container-in-container' subnet. Your target subnet is too small: /${target_subnet_part}. It needs to be at least a /16."
  exit 1
fi

# The whole point of this script is to provide a deterministic way to compute
# container networks. We use the host address part to compute a new subnet.
# If the container's subnet is too large, the host part will be too large and
# we won't be able to compute our subnet.
if (( (target_subnet_part + 8) > container_netmask_cidr )); then
  echo 1>&2 "Can't compute a 'container-in-container' subnet. There isn't enough room: Target: /${target_subnet_part}; eth0 subnet: /${container_netmask_cidr}. We need room for at least 256 addresses (a difference of at least 8 between 'target' and 'eth0 subnet')."
  exit 1
fi

# Get the host address part of the eth0 IP address as an int (so we can shift it)
host_address_int=$(
  ip2int $(
      printf "%d.%d.%d.%d\n" \
      "$(( (i1 | m1) - m1 ))" \
      "$(( (i2 | m2) - m2 ))" \
      "$(( (i3 | m3) - m3 ))" \
      "$(( (i4 | m4) - m4 ))"
  )
)

# Shift the host address 8 bits to the left then convert it back to an IP address.
host_address_shifted=$(int2ip "$(( host_address_int << 8 ))")

# Get the pieces of the shifted host address.
IFS=. read -r ha1 ha2 ha3 ha4 <<< $host_address_shifted

# Compute our subnet.
cell_subnet=$(
  printf "%d.%d.%d.%d/%d" \
    "$(( (ti1 & m1) | ha1 ))" \
    "$(( (ti2 & m2) | ha2 ))" \
    "$(( (ti3 & m3) | ha3 ))" \
    "$(( (ti4 & m4) | ha4 ))" \
    "$(( target_subnet_part + 8 ))"
)

perl -p -i -e "s@^properties.garden.network_pool:.*@properties.garden.network_pool: ${cell_subnet}@" /opt/hcf/env2conf.yml

