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
    override.vm.box = "https://cf-opensusefs2.s3.amazonaws.com/vagrant/scf-virtualbox-v2.0.4.box"
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
           puts <<-BRIDGE_WARNING
Your default interface is not a host bridge.
When using the libvirt provider, you must set up a host bridge interface in order for the VM
to be accessible on the public IP from the KVM host.
If using wicked, you can put the following in /etc/sysconfig/network/ifcfg-#{default_if}:
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
then run `wicked ifreload all`, and try `vagrant up --provider libvirt` again
BRIDGE_WARNING
        end
      end
      user_warned_about_bridge = true
    end

    override.vm.box = "https://cf-opensusefs2.s3.amazonaws.com/vagrant/scf-libvirt-v2.0.4.box"
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

  # We can't run the VMware specific mounting in a provider override,
  # because as documentation states, ordering is outside in:
  # https://www.vagrantup.com/docs/provisioning/basic_usage.html
  #
  # This would mean that mounting the shared folders would always be the last
  # thing done, when we need it to be the first
  config.vm.provision "shell", privileged: false, inline: <<-SCRIPT
    # Only run if we're on Workstation or Fusion
    if sudo dmidecode -s system-product-name | grep -qi vmware; then
      echo "Waiting for mounts to be available ..."
      retries=1
      mounts_available="no"
      until [ "$mounts_available" == "yes"  ] || [ "$retries" -gt 120 ]; do
        sleep 1
        retries=$((retries+1))

        if [ -d "/mnt/hgfs/scf/src" ]; then
          mounts_available="yes"
        fi
      done

      if hash vmhgfs-fuse 2>/dev/null; then
        echo "Mounts available after ${retries} seconds."

        if [ ! -d "/home/vagrant/scf" ]; then
          echo "Sharing directories in the VMware world ..."
          mkdir -p /home/vagrant/scf
          mkdir -p /home/vagrant/.bosh

          sudo vmhgfs-fuse .host:scf /home/vagrant/scf -o allow_other
          sudo vmhgfs-fuse .host:bosh /home/vagrant/.bosh -o allow_other
        fi
      else
        >&2 echo "Timed out waiting for mounts load after ${retries} seconds."
        exit 1
      fi
    fi
  SCRIPT

  config.vm.provision "shell", privileged: true, env: ENV.select { |e|
    %w(http_proxy https_proxy no_proxy).include? e.downcase
  }, inline: <<-SHELL
    set -e
    for var in no_proxy http_proxy https_proxy NO_PROXY HTTP_PROXY HTTPS_PROXY ; do
       if test -n "${!var}" ; then
          echo "${var}=${!var}" | tee -a /etc/environment
       fi
    done
    echo Proxy setup of the host, saved ...
  SHELL

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

    # Get proxy configuration here
    source /etc/environment
    export no_proxy http_proxy https_proxy NO_PROXY HTTP_PROXY HTTPS_PROXY

    # Install development tools
    (
      cd "${HOME}/scf"
      ${HOME}/bin/direnv exec ${HOME}/scf/bin/dev/install_tools.sh
    )

  SHELL

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    set -e
    echo 'if test -e /mnt/hgfs ; then /mnt/hgfs/scf/bin/dev/setup_vmware_mounts.sh ; fi' >> .profile

    echo 'export PATH=$PATH:/home/vagrant/scf/output/bin/' >> .profile
    echo 'export PATH=$PATH:/home/vagrant/scf/container-host-files/opt/hcf/bin/' >> .profile
    echo 'test -f /home/vagrant/scf/personal-setup && . /home/vagrant/scf/personal-setup' >> .profile

    direnv exec /home/vagrant/scf make -C /home/vagrant/scf copy-compile-cache

    echo -e "\n\nAll done - you can \e[1;96mvagrant ssh\e[0m\n\n"
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
