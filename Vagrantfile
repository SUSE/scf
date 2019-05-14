# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'resolv'
require 'securerandom'

def base_net_config
  base_config = {
    use_dhcp_assigned_default_route: true
  }
  if (ENV.keys & ["VAGRANT_KVM_BRIDGE", "VAGRANT_VBOX_BRIDGE"]).empty?
    if ENV.include? "VAGRANT_DHCP"
      # Use dhcp if VAGRANT_DHCP is set. This only applies to NAT networking, as
      # bridged networking uses type: bridged (even though the virtual interface still
      # gets its IP from dhcp). If not using dhcp, the VM will use the IP cf-dev.io points to.
      base_config[:type] = "dhcp"
    else
      base_config[:ip] = Resolv.getaddress "cf-dev.io"
    end
  end
  base_config
end

def provision(config, home, vm_registry_mirror, mounted_custom_setup_scripts)
  config.ssh.forward_env = ["FISSILE_COMPILATION_CACHE_CONFIG"]

  config.vm.provision :shell, privileged: true, path: "vagrant/loop_kernel_module.sh"
  config.vm.provision :shell, privileged: true, path: "vagrant/enable_ssh_env_forwarding.sh"
  config.vm.provision :shell, privileged: true, env: ENV.select { |e|
    %w(http_proxy https_proxy no_proxy).include? e.downcase
  }, path: "vagrant/write_proxy_vars_to_environment.sh"
  config.vm.provision :shell, privileged: false, path: "vagrant/setup_direnv.sh"
  config.vm.provision :shell, privileged: true, path: "vagrant/install_common_dev_tools.sh", args: [home, vm_registry_mirror]
  config.vm.provision :shell, privileged: true, path: "vagrant/ensure_kubelet_is_running.sh"
  config.vm.provision :shell, privileged: false, path: "vagrant/setup_storage_class.sh"
  config.vm.provision :shell, privileged: false, path: "vagrant/wait_pods_ready.sh"
  config.vm.provision :shell, privileged: false,
                      env: {"FISSILE_COMPILATION_CACHE_CONFIG" => ENV["FISSILE_COMPILATION_CACHE_CONFIG"]},
                      path: "vagrant/restore_fissile_cache.sh"
  config.vm.provision "shell", privileged: false, path: "vagrant/provision_custom_scripts.sh", args: [mounted_custom_setup_scripts]

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    echo -e "\n\nAll done - you can \e[1;96mvagrant ssh\e[0m\n\n"
  SHELL
end

Vagrant.configure(2) do |config|
  vm_memory = ENV.fetch('SCF_VM_MEMORY', ENV.fetch('VM_MEMORY', 10 * 1024)).to_i
  vm_cpus = ENV.fetch('SCF_VM_CPUS', ENV.fetch('VM_CPUS', 4)).to_i
  vm_box_version = ENV.fetch('SCF_VM_BOX_VERSION', ENV.fetch('VM_BOX_VERSION', '2.0.17'))
  vm_registry_mirror = ENV.fetch('SCF_VM_REGISTRY_MIRROR', ENV.fetch('VM_REGISTRY_MIRROR', ''))

  HOME = "/home/vagrant"
  FISSILE_CACHE_DIR = "#{HOME}/.fissile"
  FISSILE_CACHE_SIZE = ENV.fetch('VM_FISSILE_CACHE_SIZE', 120).to_i
  KUBERNETES_HOSTPATH_DIR = "/tmp/hostpath_pv"
  KUBERNETES_HOSTPATH_SIZE = ENV.fetch('KUBERNETES_HOSTPATH_SIZE', 120).to_i

  # Set this environment variable pointing to a directory containing shell scripts to be executed as
  # part of the provisioning of the Vagrant machine. If the directory contains a subdirectory called
  # `provision.d`, every script inside this folder will be executed as part of the provisioning of
  # the Vagrant VM.
  custom_setup_scripts_env = "SCF_VM_CUSTOM_SETUP_SCRIPTS"
  # The target directory where the custom setup scripts are mounted if the custom config scripts env
  # is set.
  mounted_custom_setup_scripts = "#{HOME}/.config/custom_vagrant_setup_scripts"

  config.vm.provider "virtualbox" do |vb, override|
    # Need to shorten the URL for Windows' sake.
    override.vm.box = "https://cf-opensusefs2.s3.amazonaws.com/vagrant/scf-virtualbox-v#{vm_box_version}.box"
    vb_net_config = base_net_config
    if ENV.include? "VAGRANT_VBOX_BRIDGE"
      vb_net_config[:bridge] = ENV.fetch("VAGRANT_VBOX_BRIDGE")
      override.vm.network "public_network", vb_net_config
    else
      # Create a private network, which allows host-only access to the machine.
      override.vm.network "private_network", vb_net_config
    end

    vb.memory = vm_memory.to_s
    vb.cpus = vm_cpus

    vb.customize ['modifyvm', :id, '--paravirtprovider', 'minimal']

    default_machine_folder = `VBoxManage list systemproperties | grep "Default machine folder"`
    vb_machine_folder = default_machine_folder.split(':')[1].strip()

    # Create and attach a disk for Fissile cache.
    fissile_cache_disk_file = "disk_fissile_cache_#{SecureRandom.hex(16)}.vdi"
    fissile_cache_disk = File.join(vb_machine_folder, fissile_cache_disk_file)
    unless File.exist?(fissile_cache_disk)
      vb.customize ['createhd', '--filename', fissile_cache_disk, '--format', 'VDI', '--size', FISSILE_CACHE_SIZE * 1024]
    end
    vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', fissile_cache_disk]

    # Format and mount Fissile cache disk.
    override.vm.provision "shell",
      privileged: true,
      path: "vagrant/format_and_mount_disk.sh",
      args: ["/dev/sdb", FISSILE_CACHE_DIR]

    # Create and attach a disk for Kubernetes hostPath.
    k8s_hostPath_disk_file = "disk_k8s_hostPath_#{SecureRandom.hex(16)}.vdi"
    k8s_hostPath_disk = File.join(vb_machine_folder, k8s_hostPath_disk_file)
    unless File.exist?(k8s_hostPath_disk)
      vb.customize ['createhd', '--filename', k8s_hostPath_disk, '--format', 'VDI', '--size', KUBERNETES_HOSTPATH_SIZE * 1024]
    end
    vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 2, '--device', 0, '--type', 'hdd', '--medium', k8s_hostPath_disk]

    # Format and mount Kubernetes hostPath disk.
    override.vm.provision "shell",
      privileged: true,
      path: "vagrant/format_and_mount_disk.sh",
      args: ["/dev/sdc", KUBERNETES_HOSTPATH_DIR]

    # Mount NFS volumes.
    # https://github.com/mitchellh/vagrant/issues/351
    override.vm.synced_folder ".fissile/.bosh", "#{HOME}/.bosh", type: "nfs"
    override.vm.synced_folder ".", "#{HOME}/scf", type: "nfs"

    if ENV.include? custom_setup_scripts_env
      override.vm.synced_folder ENV.fetch(custom_setup_scripts_env),
        mounted_custom_setup_scripts, type: "nfs"
    end

    # Set the shared provision scripts.
    provision(override, HOME, vm_registry_mirror, mounted_custom_setup_scripts)
  end

  config.vm.provider "libvirt" do |libvirt, override|
    override.vm.box = "https://cf-opensusefs2.s3.amazonaws.com/vagrant/scf-libvirt-v#{vm_box_version}.box"
    libvirt.driver = "kvm"
    libvirt_net_config = base_net_config
    libvirt_net_config[:nic_model_type] = "virtio"
    if ENV.include? "VAGRANT_KVM_BRIDGE"
      libvirt_net_config[:dev] = ENV["VAGRANT_KVM_BRIDGE"]
      libvirt_net_config[:type] = "bridge"
      override.vm.network "public_network", libvirt_net_config
    else
      # Create a private network, which allows host-only access to the machine.
      override.vm.network "private_network", libvirt_net_config
    end

    libvirt.memory = vm_memory
    libvirt.cpus = vm_cpus
    libvirt.random model: 'random'

    # Create and attach a disk for Fissile cache.
    libvirt.storage :file, :size => "#{FISSILE_CACHE_SIZE}G"

    # Format and mount Fissile cache disk.
    override.vm.provision "shell",
      privileged: true,
      path: "vagrant/format_and_mount_disk.sh",
      args: ["/dev/vdb", FISSILE_CACHE_DIR]

    # Create and attach a disk for Kubernetes hostPath.
    libvirt.storage :file, :size => "#{KUBERNETES_HOSTPATH_SIZE}G"

    # Format and mount Kubernetes hostPath disk.
    override.vm.provision "shell",
      privileged: true,
      path: "vagrant/format_and_mount_disk.sh",
      args: ["/dev/vdc", KUBERNETES_HOSTPATH_DIR]

    # Mount NFS volumes.
    override.vm.synced_folder ".fissile/.bosh", "#{HOME}/.bosh", type: "nfs"
    override.vm.synced_folder ".", "#{HOME}/scf", type: "nfs"

    if ENV.include? custom_setup_scripts_env
      override.vm.synced_folder ENV.fetch(custom_setup_scripts_env),
        mounted_custom_setup_scripts, type: "nfs"
    end

    # Set the shared provision scripts.
    provision(override, HOME, vm_registry_mirror, mounted_custom_setup_scripts)
  end
end
