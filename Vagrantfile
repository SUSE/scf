# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "ubuntu/trusty64"

  # Create port forward mappings
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.network "forwarded_port", guest: 443, host: 443
  config.vm.network "forwarded_port", guest: 4443, host: 4443

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  config.vm.provider "virtualbox" do |vb|
    # Customize the amount of memory on the VM:
    vb.memory = "8096"

    # If you need to debug stuff
    # vb.gui = true
  end

  config.vm.synced_folder ".fissile/.bosh", "/home/vagrant/.bosh"
  config.vm.synced_folder ".", "/home/vagrant/hcf"

  config.vm.provision "shell", inline: <<-SHELL
    /home/vagrant/hcf/bin/docker/install_kernel.sh
  SHELL

  config.vm.provision :reload

  config.vm.provision "file", source: "./bootstrap-config/etcd.conf", destination: "/tmp/etcd.conf"

  config.vm.provision "shell", inline: <<-SHELL
    /home/vagrant/hcf/bin/docker/install_etcd.sh
    /home/vagrant/hcf/bin/docker/configure_etcd.sh "hcf" "192.168.33.10"
    /home/vagrant/hcf/bin/docker/install_docker.sh "192.168.33.10" "15.126.242.125:5000" "vagrant"
  SHELL

  config.vm.provision :reload

  config.vm.provision "shell", inline: <<-SHELL
    /home/vagrant/hcf/bin/docker/setup_overlay_network.sh "192.168.252.0/24" "192.168.252.1"
    /home/vagrant/hcf/bin/dev/install_bosh.sh
    /home/vagrant/hcf/bin/dev/install_tools.sh
  SHELL

  config.vm.provision "shell", inline: <<-SHELL
    echo 'source ~/hcf/bin/.fissilerc' >> .profile
    echo 'source ~/hcf/bin/.runrc' >> .profile

    # TODO: investigate if this can lead to lost code if there are uncommited changes
    cd /home/vagrant/hcf
    git config --global core.symlinks true
    git submodule update --init
    /home/vagrant/hcf/src/cf-release/scripts/update
  SHELL
end
