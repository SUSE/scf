#!/bin/bash
set -e

apt-get -y install linux-headers-$(uname -r) build-essential dkms
if [ -f /etc/init.d/virtualbox-ose-guest-utils ] ; then
    # The netboot installs the VirtualBox support (old) so we have to
    # remove it
    /etc/init.d/virtualbox-ose-guest-utils stop
    rmmod vboxguest
    apt-get -y purge virtualbox-ose-guest-x11 virtualbox-ose-guest-dkms \
        virtualbox-ose-guest-utils
elif [ -f /etc/init.d/virtualbox-guest-utils ] ; then
    /etc/init.d/virtualbox-guest-utils stop
    apt-get -y purge virtualbox-guest-utils virtualbox-guest-dkms virtualbox-guest-x11
fi

# Installing the virtualbox guest additions
VBOX_VERSION=$(cat /home/vagrant/.vbox_version)
VBOX_ISO=/home/vagrant/VBoxGuestAdditions_${VBOX_VERSION}.iso
cd /tmp

if [ ! -f $VBOX_ISO ] ; then
    wget -q http://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso \
        -O $VBOX_ISO
fi
mount -o loop $VBOX_ISO /mnt
# Suppress "Could not find the X.Org or XFree86 Window System, skipping."
sh /mnt/VBoxLinuxAdditions.run >/dev/null || true
umount /mnt

rm $VBOX_ISO

apt-get -y remove linux-headers-$(uname -r)
apt-get -y autoremove
