# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.


def os_is_osx?
  `uname`.strip == 'Darwin'
end

def default_if_osx
  `route get default | grep interface`.split(" ").last
end

def default_if_linux
  `/sbin/route | grep default`.split(" ").last
end

# Returns the name of the default interface
def default_if
  @default_if_memo ||= os_is_osx? ? default_if_osx : default_if_linux
end

def interface_is_bridge?(interface)
  `/usr/sbin/brctl show | cut -f1 | grep '^#{interface}$'`.strip.length > 0
end

# While VBox on Linux allows bridging without a host device, there's no easy way
# to check the provider from the Vagrantfile (provider-specific config blocks
# still run on the wrong providers) so assume libvirt on linux deployments
#
# It's also worth noting that the Vagrant libvirt provider (KVM) typically uses
# 'direct' type interfaces for public_network interfaces. While these *do* work
# without a host bridge interface, the host VM is unable to route to IPs the VM
# receives this way. See https://libvirt.org/formatnetwork.html#examplesDirect
def host_bridge_available?
  # Exploit the fact that puts returns nil, which is falsy
  if os_is_osx?
    puts "Bridged networking not implemented on OSX"
  elsif ! default_if
    puts "No default interface detected"
  elsif ! File.file? "/usr/sbin/brctl"
    puts "'brctl' tool not found. Have you installed bridge-utils"
  elsif ! interface_is_bridge?(default_if)
    warning_env = {
      "COMMAND"    => "vagrant up --provider=libvirt",
      "DEFAULT_IF" => default_if
    }
    puts system(warning_env, "bin/common/warn_no_bridge.sh")
  else
    true
  end
end

def bridged_net_linux?()
  @bridged_net_memo ||= ENV.fetch("VAGRANT_BRIDGED", false) && host_bridge_available?
end

# In theory, vbox could manage a bridged deployment if the interface is not wireless
# But for now, we'll assume vbox is primarily used for osx deployments, which means
# a wired interface may not be available
def bridged_net_osx?
  false
end

def bridged_net?
  @bridged_net_memo ||= os_is_osx? ? bridged_net_linux? : bridged_net_osx?
end

def net_dhcp?
  ENV.fetch("VAGRANT_DHCP", false) ? true : bridged_net?
end

Vagrant.configure(2) do |config|
  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.

  # Create port forward mappings
  # These are only required when using private (NAT) networking, and want
  # VM access from a client not on the VM host
  #
  # config.vm.network "forwarded_port", guest: 80, host: 80
  # config.vm.network "forwarded_port", guest: 443, host: 443
  # config.vm.network "forwarded_port", guest: 4443, host: 4443
  # config.vm.network "forwarded_port", guest: 8501, host: 8501

  vm_memory = ENV.fetch('VM_MEMORY', 10 * 1024).to_i
  vm_cpus = ENV.fetch('VM_CPUS', 4).to_i

  vb_net_config = {}
  if bridged_net?
    vb_net_config[:using_dhcp_assigned_default_route] = true
  else
    # Use dhcp if VAGRANT_DHCP is set. This only applies to NAT networking, as
    # bridged networking uses type: bridged (even though the virtual interface still
    # gets its IP from dhcp. If not using dhcp, the VM will use the 192.168.77.77 IP
    if ENV.fetch("VAGRANT_DHCP", false)
      vb_net_config[:type] = "dhcp"
    else
      vb_net_config[:ip] = "192.168.77.77"
    end
  end
  # Create a clone of this, otherwise it gets mutated in both providers' sections
  libvirt_net_config = vb_net_config.clone

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.

  config.vm.provider "virtualbox" do |vb, override|
    # Need to shorten the URL for Windows' sake
    override.vm.box = "https://cf-opensusefs2.s3.amazonaws.com/vagrant/scf-virtualbox-v2.0.5.box"
    if bridged_net?
      vb_net_config[:bridged] = default_if
      override.vm.network "public_network", vb_net_config
    else
      override.vm.network "private_network", vb_net_config
    end
    # Customize the amount of memory on the VM:
    vb.memory = vm_memory.to_s
    vb.cpus = vm_cpus
    # If you need to debug stuff
    # vb.gui = true
    vb.customize ['modifyvm', :id, '--paravirtprovider', 'minimal']

    # https://github.com/mitchellh/vagrant/issues/351
    override.vm.synced_folder ".fissile/.bosh", "/home/vagrant/.bosh", type: "nfs"
    override.vm.synced_folder ".", "/home/vagrant/scf", type: "nfs"
  end

# Currently not built for vmware_fusion
# config.vm.provider "vmware_fusion" do |vb, override|
#   override.vm.box="https://cf-opensusefs2.s3.amazonaws.com/vagrant/scf-vmware-v2.0.3.box"
#
#   # Customize the amount of memory on the VM:
#   vb.memory = vm_memory.to_s
#   vb.cpus = vm_cpus
#   # If you need to debug stuff
#   # vb.gui = true
#
#   # `vmrun getGuestIPAddress` often returns the address of the docker0 bridge instead of eth0 :(
#   vb.enable_vmrun_ip_lookup = false
#
#   # Disable default synced folder
#   config.vm.synced_folder ".", "/vagrant", disabled: true
#
#   # Enable HGFS
#   vb.vmx["isolation.tools.hgfs.disable"] = "FALSE"
#
#   # Must be equal to the total number of shares
#   vb.vmx["sharedFolder.maxnum"] = "2"
#
#   # Configure shared folders
#   VMwareHacks.configure_shares(vb)
# end

# Currently not built for vmware_workstation
#  config.vm.provider "vmware_workstation" do |vb, override|
#    override.vm.box="https://cf-opensusefs2.s3.amazonaws.com/vagrant/scf-vmware-v2.0.3.box"
#
#    # Customize the amount of memory on the VM:
#    vb.memory = vm_memory.to_s
#    vb.cpus = vm_cpus
#    # If you need to debug stuff
#    # vb.gui = true
#
#    # Disable default synced folder
#    config.vm.synced_folder ".", "/vagrant", disabled: true
#
#    # Enable HGFS
#    vb.vmx["isolation.tools.hgfs.disable"] = "FALSE"
#
#    # Must be equal to the total number of shares
#    vb.vmx["sharedFolder.maxnum"] = "2"
#
#    # Configure shared folders
#    VMwareHacks.configure_shares(vb)
#  end

  config.vm.provider "libvirt" do |libvirt, override|

    override.vm.box = "https://cf-opensusefs2.s3.amazonaws.com/vagrant/scf-libvirt-v2.0.5.box"
    libvirt.driver = "kvm"
    libvirt_net_config[:nic_model_type] = "virtio"
    if bridged_net?
      libvirt_net_config[:dev] = default_if
      libvirt_net_config[:type] = "bridge"
      override.vm.network "public_network", libvirt_net_config
    else
      override.vm.network "private_network", libvirt_net_config
    end
    # Allow downloading boxes from sites with self-signed certs
    libvirt.memory = vm_memory
    libvirt.cpus = vm_cpus
    override.vm.synced_folder ".fissile/.bosh", "/home/vagrant/.bosh", type: "nfs"
    override.vm.synced_folder ".", "/home/vagrant/scf", type: "nfs"
  end

  config.vm.provision "shell", privileged: true, env: ENV.select { |e|
    %w(http_proxy https_proxy no_proxy).include? e.downcase
  }, path: "bin/common/write_proxy_vars_to_environment.sh" 

  # set up direnv so we can pick up fissile configuration
  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    set -o errexit -o nounset
    mkdir -p ${HOME}/bin
    wget -O ${HOME}/bin/direnv --no-verbose \
      https://github.com/direnv/direnv/releases/download/v2.11.3/direnv.linux-amd64
    chmod a+x ${HOME}/bin/direnv
    echo 'eval "$(${HOME}/bin/direnv hook bash)"' >> ${HOME}/.bashrc
    ln -s ${HOME}/scf/bin/dev/vagrant-envrc ${HOME}/.envrc
    ${HOME}/bin/direnv allow ${HOME}
    ${HOME}/bin/direnv allow ${HOME}/scf
  SHELL

  config.vm.provision :shell, privileged: true, inline: "chown vagrant:users /home/vagrant/.fissile"
  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    set -o errexit -o xtrace
    echo 'if test -e /mnt/hgfs ; then /mnt/hgfs/scf/bin/dev/setup_vmware_mounts.sh ; fi' >> .profile

    echo 'export PATH=$PATH:/home/vagrant/scf/container-host-files/opt/hcf/bin/' >> .profile
    echo 'test -f /home/vagrant/scf/personal-setup && . /home/vagrant/scf/personal-setup' >> .profile

    direnv exec /home/vagrant/scf make -C /home/vagrant/scf copy-compile-cache

    echo -e "\n\nAll done - you can \e[1;96mvagrant ssh\e[0m\n\n"
  SHELL

  # Install common and dev tools
  config.vm.provision :shell, privileged: true, inline: <<-SHELL
    set -o errexit -o xtrace
    # Get proxy configuration here
    export HOME=/home/vagrant
    cd "${HOME}/scf"
    ${HOME}/bin/direnv exec ${HOME}/scf/bin/common/install_tools.sh
    ${HOME}/bin/direnv exec ${HOME}/scf/bin/dev/install_tools.sh
  SHELL
end

# module VMwareHacks
#
#   # Here we manually define the shared folder for VMware-based providers
#   def VMwareHacks.configure_shares(vb)
#     current_dir = File.dirname(__FILE__)
#     bosh_cache = File.join(current_dir, '.fissile/.bosh')
#
#     # share . in the box
#     vb.vmx["sharedFolder0.present"] = "TRUE"
#     vb.vmx["sharedFolder0.enabled"] = "TRUE"
#     vb.vmx["sharedFolder0.readAccess"] = "TRUE"
#     vb.vmx["sharedFolder0.writeAccess"] = "TRUE"
#     vb.vmx["sharedFolder0.hostPath"] = current_dir
#     vb.vmx["sharedFolder0.guestName"] = "scf"
#     vb.vmx["sharedFolder0.expiration"] = "never"
#     vb.vmx["sharedfolder0.followSymlinks"] = "TRUE"
#
#     # share .fissile/.bosh in the box
#     vb.vmx["sharedFolder1.present"] = "TRUE"
#     vb.vmx["sharedFolder1.enabled"] = "TRUE"
#     vb.vmx["sharedFolder1.readAccess"] = "TRUE"
#     vb.vmx["sharedFolder1.writeAccess"] = "TRUE"
#     vb.vmx["sharedFolder1.hostPath"] = bosh_cache
#     vb.vmx["sharedFolder1.guestName"] = "bosh"
#     vb.vmx["sharedFolder1.expiration"] = "never"
#     vb.vmx["sharedfolder1.followSymlinks"] = "TRUE"
#   end
# end
