
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
  # These are not normally required, since all access happens on the
  # 192.168.77.77 IP address
  #
  # config.vm.network "forwarded_port", guest: 80, host: 80
  # config.vm.network "forwarded_port", guest: 443, host: 443
  # config.vm.network "forwarded_port", guest: 4443, host: 4443
  # config.vm.network "forwarded_port", guest: 8501, host: 8501


  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network "private_network", ip: "192.168.77.77"

  config.vm.provider "virtualbox" do |vb, override|
    # Need to shorten the URL for Windows' sake
    override.vm.box = "https://api.mpce.hpelabs.net:8080/v1/AUTH_7b52c1fb73ad4568bbf5e90bead84e21/hcf-vagrant-box-images/hcf-virtualbox-v1.0.0.box"
    # Customize the amount of memory on the VM:
    vb.memory = "6144"
    vb.cpus = 4
    # If you need to debug stuff
    # vb.gui = true

    override.vm.synced_folder ".fissile/.bosh", "/home/vagrant/.bosh"
    override.vm.synced_folder ".", "/home/vagrant/hcf"
  end

  config.vm.provider "vmware_fusion" do |vb, override|
    override.vm.box="https://api.mpce.hpelabs.net:8080/v1/AUTH_7b52c1fb73ad4568bbf5e90bead84e21/hcf-vagrant-box-images/hcf-vmware-v1.0.1.box"

    # Customize the amount of memory on the VM:
    vb.memory = "6144"
    vb.cpus = 4
    # If you need to debug stuff
    # vb.gui = true

    override.vm.synced_folder ".fissile/.bosh", "/home/vagrant/.bosh"
    override.vm.synced_folder ".", "/home/vagrant/hcf"
  end

  config.vm.provider "libvirt" do |libvirt, override|
    override.vm.box = "https://api.mpce.hpelabs.net:8080/v1/AUTH_7b52c1fb73ad4568bbf5e90bead84e21/hcf-vagrant-box-images/hcf-libvirt-v1.0.1.box"
    libvirt.driver = "kvm"
    # Allow downloading boxes from sites with self-signed certs
    override.vm.box_download_insecure = true
    libvirt.memory = 8192
    libvirt.cpus = 4
    override.vm.synced_folder ".fissile/.bosh", "/home/vagrant/.bosh", type: "nfs"
    override.vm.synced_folder ".", "/home/vagrant/hcf", type: "nfs"
  end

  unless OS.windows?
    config.vm.provision "shell", inline: <<-SHELL
        if [ ! -e "/home/vagrant/hcf/src/cf-release/.git" ]; then
          echo "Looks like the cf-release submodule was not initialized" >&2
          echo "Did you run 'git submodule update --init --recursive'?" >&2
          exit 1
        fi
    SHELL
  end

  config.vm.provision :reload

  config.vm.provision "shell", inline: <<-SHELL
    set -e

    # Configure Docker things
    sudo /home/vagrant/hcf/container-host-files/opt/hcf/bin/docker/configure_docker.sh /dev/sdb 64 4
    /home/vagrant/hcf/container-host-files/opt/hcf/bin/docker/setup_network.sh "172.20.10.0/24" "172.20.10.1"
    /home/vagrant/hcf/container-host-files/opt/hcf/bin/docker/create_docker_dns_server.sh

    # Install development tools
    /home/vagrant/hcf/bin/dev/install_tools.sh

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

    echo 'export PATH=$PATH:/home/vagrant/hcf/container-host-files/opt/hcf/bin/' >> .profile
    echo "alias hcf-status-watch='watch --color hcf-status'" >> .profile
  SHELL

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    # Start a new shell to pick up .profile changes
    set -e
    cd /home/vagrant/hcf
    make copy-compile-cache

    echo -e "\n\nAll done - you can \e[1;96mvagrant ssh\e[0m\n\n"
  SHELL
end

module OS
  def OS.windows?
      (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end
end
