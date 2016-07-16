
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
    override.vm.box = "https://s3-us-west-2.amazonaws.com/hcf-vagrant-box-images/hcf-virtualbox-v1.0.9.box"

    # Customize the amount of memory on the VM:
    vb.memory = "6144"
    vb.cpus = 4
    # If you need to debug stuff
    # vb.gui = true
    vb.customize ['modifyvm', :id, '--paravirtprovider', 'minimal']

    override.vm.synced_folder ".fissile/.bosh", "/home/vagrant/.bosh"
    override.vm.synced_folder ".", "/home/vagrant/hcf"
  end

  config.vm.provider "vmware_fusion" do |vb, override|
    override.vm.box="https://s3-us-west-2.amazonaws.com/hcf-vagrant-box-images/hcf-vmware-v1.0.9.box"

    # Customize the amount of memory on the VM:
    vb.memory = "6144"
    vb.cpus = 4
    # If you need to debug stuff
    # vb.gui = true

    # `vmrun getGuestIPAddress` often returns the address of the docker0 bridge instead of eth0 :(
    vb.enable_vmrun_ip_lookup = false

    # Disable default synced folder
    config.vm.synced_folder ".", "/vagrant", disabled: true

    # Enable HGFS
    vb.vmx["isolation.tools.hgfs.disable"] = "FALSE"

    # Must be equal to the total number of shares
    vb.vmx["sharedFolder.maxnum"] = "2"

    # Configure shared folders
    VMwareHacks.configure_shares(vb)
  end

  config.vm.provider "vmware_workstation" do |vb, override|
    override.vm.box="https://s3-us-west-2.amazonaws.com/hcf-vagrant-box-images/hcf-vmware-v1.0.9.box"

    # Customize the amount of memory on the VM:
    vb.memory = "6144"
    vb.cpus = 4
    # If you need to debug stuff
    # vb.gui = true

    # Disable default synced folder
    config.vm.synced_folder ".", "/vagrant", disabled: true

    # Enable HGFS
    vb.vmx["isolation.tools.hgfs.disable"] = "FALSE"

    # Must be equal to the total number of shares
    vb.vmx["sharedFolder.maxnum"] = "2"

    # Configure shared folders
    VMwareHacks.configure_shares(vb)
  end

  config.vm.provider "libvirt" do |libvirt, override|
    override.vm.box = "https://s3-us-west-2.amazonaws.com/hcf-vagrant-box-images/hcf-libvirt-v1.0.9.box"
    libvirt.driver = "kvm"
    # Allow downloading boxes from sites with self-signed certs
    override.vm.box_download_insecure = true
    libvirt.memory = 8192
    libvirt.cpus = 4
    override.vm.synced_folder ".fissile/.bosh", "/home/vagrant/.bosh", type: "nfs"
    override.vm.synced_folder ".", "/home/vagrant/hcf", type: "nfs"
  end

  # We can't run the VMware specific mounting in a provider override,
  # because as documentation states, ordering is inside out:
  # https://www.vagrantup.com/docs/provisioning/basic_usage.html
  #
  # This would mean that mounting the shared folders would always be the last
  # thing done, when we need it to be the first
  config.vm.provision "shell", privileged: false, inline: <<-SCRIPT
    # Only run if we're on Workstation or Fusion
    if hash vmhgfs-fuse 2>/dev/null; then
      if [ ! -d "/home/vagrant/hcf" ]; then
        echo "Sharing directories in the VMware world ..."

        mkdir -p /home/vagrant/hcf
        mkdir -p /home/vagrant/.bosh

        sudo vmhgfs-fuse .host:hcf /home/vagrant/hcf -o allow_other
        sudo vmhgfs-fuse .host:bosh /home/vagrant/.bosh -o allow_other
      fi
    fi
  SCRIPT

  unless OS.windows?
    config.vm.provision "shell", privileged: false, inline: <<-SHELL
        if [ ! -e "/home/vagrant/hcf/src/cf-release/.git" ]; then
          echo "Looks like the cf-release submodule was not initialized" >&2
          echo "Did you run 'git submodule update --init --recursive'?" >&2
          exit 1
        fi
    SHELL
  end

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    set -e

    # Configure Docker things
    sudo /home/vagrant/hcf/container-host-files/opt/hcf/bin/docker/configure_docker.sh /dev/sdb 64 4
    /home/vagrant/hcf/container-host-files/opt/hcf/bin/docker/setup_network.sh "172.20.10.0/24" "172.20.10.1"

    # Install development tools
    /home/vagrant/hcf/bin/dev/install_tools.sh

    mkdir -p /home/vagrant/tmp

    chown vagrant /home/vagrant/bin
    chown vagrant /home/vagrant/bin/*
    chown vagrant /home/vagrant/tools
    chown vagrant /home/vagrant/tools/*
    chown vagrant /home/vagrant/tmp
  SHELL

  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    ulimit -l unlimited

    # Allowed number of open file descriptors
    ulimit -n 100000

    # Ephemeral port range
    echo "1024 65535" > /proc/sys/net/ipv4/ip_local_port_range

    # TCP_FIN_TIMEOUT
    # This setting determines the time that must elapse before TCP/IP can release a closed connection and reuse
    # its resources. During this TIME_WAIT state, reopening the connection to the client costs less than establishing
    # a new connection. By reducing the value of this entry, TCP/IP can release closed connections faster, making more
    # resources available for new connections. Addjust this in the presense of many connections sitting in the
    # TIME_WAIT state:
    echo 5 > /proc/sys/net/ipv4/tcp_fin_timeout

    # TCP_TW_RECYCLE
    # It enables fast recycling of TIME_WAIT sockets. The default value is 0 (disabled). The sysctl documentation
    # incorrectly states the default as enabled. It can be changed to 1 (enabled) in many cases. Known to cause some
    # issues with hoststated (load balancing and fail over) if enabled, should be used with caution.
    echo 0 > /proc/sys/net/ipv4/tcp_tw_recycle

    # TCP_TW_REUSE
    # This allows reusing sockets in TIME_WAIT state for new connections when it is safe from protocol viewpoint.
    # Default value is 0 (disabled). It is generally a safer alternative to tcp_tw_recycle
    echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse

    # Allow a few more queued connections than are allowed by default
    echo 1024 > /proc/sys/net/core/somaxconn
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

module VMwareHacks

  # Here we manually define the shared folder for VMware-based providers
  def VMwareHacks.configure_shares(vb)
    current_dir = File.dirname(__FILE__)
    bosh_cache = File.join(current_dir, '.fissile/.bosh')

    # share . in the box
    vb.vmx["sharedFolder0.present"] = "TRUE"
    vb.vmx["sharedFolder0.enabled"] = "TRUE"
    vb.vmx["sharedFolder0.readAccess"] = "TRUE"
    vb.vmx["sharedFolder0.writeAccess"] = "TRUE"
    vb.vmx["sharedFolder0.hostPath"] = current_dir
    vb.vmx["sharedFolder0.guestName"] = "hcf"
    vb.vmx["sharedFolder0.expiration"] = "never"
    vb.vmx["sharedfolder0.followSymlinks"] = "TRUE"

    # share .fissile/.bosh in the box
    vb.vmx["sharedFolder1.present"] = "TRUE"
    vb.vmx["sharedFolder1.enabled"] = "TRUE"
    vb.vmx["sharedFolder1.readAccess"] = "TRUE"
    vb.vmx["sharedFolder1.writeAccess"] = "TRUE"
    vb.vmx["sharedFolder1.hostPath"] = bosh_cache
    vb.vmx["sharedFolder1.guestName"] = "bosh"
    vb.vmx["sharedFolder1.expiration"] = "never"
    vb.vmx["sharedfolder1.followSymlinks"] = "TRUE"
  end
end

module OS
  def OS.windows?
      (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end
end
