
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

  config.vm.provider "vmware_fusion" do |vb, override|
    override.vm.box = "https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/hcf-vagrant-box/hcf-vmware-v0.box"
    # Customize the amount of memory on the VM:
    vb.memory = "8192"
    # If you need to debug stuff
    # vb.gui = true

    override.vm.synced_folder ".fissile/.bosh", "/home/vagrant/.bosh"
    override.vm.synced_folder ".", "/home/vagrant/hcf"
  end

  config.vm.provider "virtualbox" do |vb, override|
    override.vm.box = "https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/hcf-vagrant-box/hcf-virtualbox-v0.box"
    # Customize the amount of memory on the VM:
    vb.memory = "16192"
    vb.cpus = 8
    # If you need to debug stuff
    # vb.gui = true

    override.vm.synced_folder ".fissile/.bosh", "/home/vagrant/.bosh"
    override.vm.synced_folder ".", "/home/vagrant/hcf"
  end

  config.vm.provider "libvirt" do |libvirt, override|
    override.vm.box = "https://15.184.137.5:8080/v1/AUTH_7b52c1fb73ad4568bbf5e90bead84e21/hcf-vagrant-box-images/hcf-libvirt-v0.box"
    libvirt.driver = "kvm"
    # Allow downloading boxes from sites with self-signed certs
    override.vm.box_download_insecure = true
    libvirt.memory = 8192
    override.vm.synced_folder ".fissile/.bosh", "/home/vagrant/.bosh", type: "nfs"
    override.vm.synced_folder ".", "/home/vagrant/hcf", type: "nfs"
  end

  config.vm.provision "file", source: "./container-host-files/etc/init/etcd.conf", destination: "/tmp/etcd.conf"

  config.vm.provision "shell", inline: <<-SHELL
    if [ ! -e "/home/vagrant/hcf/src/cf-release/.git" ]; then
      echo "Looks like the cf-release submodule was not initialized" >&2
      echo "Did you run 'git submodule update --init --recursive'?" >&2
      exit 1
    fi

    /home/vagrant/hcf/container-host-files/opt/hcf/bin/docker/configure_etcd.sh "hcf" "192.168.77.77"
    /home/vagrant/hcf/container-host-files/opt/hcf/bin/docker/configure_docker.sh "192.168.77.77" "192.168.77.77"
  SHELL

  config.vm.provision :reload

  config.vm.provision "shell", inline: <<-SHELL
    set -e
    /home/vagrant/hcf/container-host-files/opt/hcf/bin/docker/setup_overlay_network.sh "192.168.252.0/24" "192.168.252.1"
    # Install development tools
    /home/vagrant/hcf/bin/dev/install_tools.sh
    # Install runtime tools
    /home/vagrant/hcf/container-host-files/opt/hcf/bin/tools/install_shyaml.sh

    mkdir -p /home/vagrant/tmp

    chown vagrant /home/vagrant/bin
    chown vagrant /home/vagrant/bin/*
    chown vagrant /home/vagrant/tools
    chown vagrant /home/vagrant/tools/*
    chown vagrant /home/vagrant/tmp
  SHELL

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    set -e
    echo 'source ~/hcf/bin/.fissilerc' >> .profile
    echo 'source ~/hcf/bin/.runrc' >> .profile
  SHELL

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    # Start a new shell to pick up .profile changes
    set -e
    cd /home/vagrant/hcf
    make copy-compile-cache
  SHELL
end
