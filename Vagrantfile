
# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.

  # Create port forward mappings
  config.vm.network "forwarded_port", guest: 80, host: 80
  config.vm.network "forwarded_port", guest: 443, host: 443
  config.vm.network "forwarded_port", guest: 4443, host: 4443
  config.vm.network "forwarded_port", guest: 8501, host: 8501

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network "private_network", ip: "192.168.77.77"

  config.vm.provider "vmware_fusion" do |vb|
    config.vm.box = "https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/hcf-vagrant-box/hcf-vmware-v0.box"
    # Customize the amount of memory on the VM:
    vb.memory = "8096"
    # If you need to debug stuff
    # vb.gui = true

    config.vm.synced_folder ".fissile/.bosh", "/home/vagrant/.bosh"
    config.vm.synced_folder ".", "/home/vagrant/hcf"
  end

  config.vm.provider "libvirt" do |libvirt|
    config.vm.box = "https://region-a.geo-1.objects.hpcloudsvc.com/v1/10070729052378/hcf-vagrant-box-images/hcf-libvirt-v0.box"
    libvirt.driver = "kvm"
    libvirt.memory = 8096

    config.vm.synced_folder ".fissile/.bosh", "/home/vagrant/.bosh", type: "nfs"
    config.vm.synced_folder ".", "/home/vagrant/hcf", type: "nfs"
  end

  config.vm.provision "file", source: "./container-host-files/etc/init/etcd.conf", destination: "/tmp/etcd.conf"

  config.vm.provision "shell", inline: <<-SHELL
    /home/vagrant/hcf/container-host-files/opt/hcf/bin/docker/configure_etcd.sh "hcf" "192.168.77.77"
    /home/vagrant/hcf/container-host-files/opt/hcf/bin/docker/configure_docker.sh "192.168.77.77" "15.126.242.125:5000"
  SHELL

  config.vm.provision :reload

  config.vm.provision "shell", inline: <<-SHELL
    /home/vagrant/hcf/container-host-files/opt/hcf/bin/docker/setup_overlay_network.sh "192.168.252.0/24" "192.168.252.1"
    /home/vagrant/hcf/bin/dev/install_bosh.sh
    /home/vagrant/hcf/bin/dev/install_tools.sh

    mkdir -p /home/vagrant/tmp

    chown vagrant /home/vagrant/bin
    chown vagrant /home/vagrant/bin/*
    chown vagrant /home/vagrant/tools
    chown vagrant /home/vagrant/tools/*
    chown vagrant /home/vagrant/tmp
  SHELL

  config.vm.provision "shell", inline: <<-SHELL
    echo 'source ~/hcf/bin/.fissilerc' >> .profile
    echo 'source ~/hcf/bin/.runrc' >> .profile

    # Install node and npm for cf-console
    # TODO: move this to packer
    wget -qO- https://deb.nodesource.com/setup_4.x | sudo bash -
    sudo apt-get install nodejs -y
    sudo npm install npm -g

    # TODO: do not run this if it's already initted
    cd /home/vagrant/hcf
    git submodule update --init
   /home/vagrant/hcf/src/cf-release/scripts/update
  SHELL
end
