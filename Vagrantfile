# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.

  vm_memory = ENV.fetch('VM_MEMORY', 10 * 1024).to_i
  vm_cpus = ENV.fetch('VM_CPUS', 4).to_i

  os=`uname`.strip
  if os == 'Darwin'
    default_if=`route get default | grep interface`.split(" ").last
  else
    default_if=`/sbin/route | grep default`.split(" ").last
  end
  # Ugly hack to warn user about not using a host bridge with libvirt
  user_warned_about_bridge = false

  net_config = {
    :use_dhcp_assigned_default_route => true
  }

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.

  config.vm.provider "virtualbox" do |vb, override|
    # Need to shorten the URL for Windows' sake
    override.vm.box = "https://cf-opensusefs2.s3.amazonaws.com/vagrant/scf-virtualbox-v2.0.5.box"
    net_config[:nic_type] = "virtio"
    net_config[:bridged] = default_if
    override.vm.network "public_network", net_config
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
    # Because Vagrant will run this section 100 times:
    if ! user_warned_about_bridge
      if ! File.file? "/usr/sbin/brctl"
         puts "'brctl' tool not found. Have you installed bridge-utils?"
      else
        if `/usr/sbin/brctl show | cut -f1 | grep '^#{default_if}$'`.empty?
          config.vm.provision :shell, path: "bin/common/warn_no_bridge.sh", env: {
            "COMMAND"    => "vagrant up --provider=libvirt",
            "DEFAULT_IF" => default_if
          }
        end
      end
      user_warned_about_bridge = true
    end

    override.vm.box = "https://cf-opensusefs2.s3.amazonaws.com/vagrant/scf-libvirt-v2.0.5.box"
    libvirt.driver = "kvm"
    net_config[:nic_model_type] = "virtio"
    net_config[:dev] = default_if
    net_config[:type] = "bridge"
    override.vm.network "public_network", net_config
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

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    set -e
    echo 'if test -e /mnt/hgfs ; then /mnt/hgfs/scf/bin/dev/setup_vmware_mounts.sh ; fi' >> .profile

    echo 'export PATH=$PATH:/home/vagrant/scf/container-host-files/opt/hcf/bin/' >> .profile
    echo 'test -f /home/vagrant/scf/personal-setup && . /home/vagrant/scf/personal-setup' >> .profile

    direnv exec /home/vagrant/scf make -C /home/vagrant/scf copy-compile-cache

    echo -e "\n\nAll done - you can \e[1;96mvagrant ssh\e[0m\n\n"
  SHELL

  # Install common and dev tools
  config.vm.provision :shell, privileged: true, inline: <<-SHELL
    # Get proxy configuration here
    export HOME=/home/vagrant
    cd "${HOME}/scf"
    ${HOME}/bin/direnv exec ${HOME}/scf/bin/common/install_tools.sh
    ${HOME}/bin/direnv exec ${HOME}/scf/bin/dev/install_tools.sh
    # Add /usr/local/bin to non-login path, since tools are installed there
    sed -i '/ENV_SUPATH/s/$/:\\/usr\\/local\\/bin/' /etc/login.defs
    sed -i 's@secure_path="\\(.*\\)"@secure_path="\\1:/usr/local/bin"@g' /etc/sudoers
  SHELL
  config.vm.provision :shell, privileged: true, inline: "chown vagrant:users /home/vagrant/.fissile"
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
