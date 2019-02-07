# -*- mode: ruby -*-
# vi: set ft=ruby :

def base_net_config
  base_config = {
    use_dhcp_assigned_default_route: true
  }
  if (ENV.keys & ["VAGRANT_KVM_BRIDGE", "VAGRANT_VBOX_BRIDGE"]).empty?
    if ENV.include? "VAGRANT_DHCP"
      # Use dhcp if VAGRANT_DHCP is set. This only applies to NAT networking, as
      # bridged networking uses type: bridged (even though the virtual interface still
      # gets its IP from dhcp). If not using dhcp, the VM will use the 192.168.77.77 IP.
      base_config[:type] = "dhcp"
    else
      base_config[:ip] = "192.168.77.77"
    end
  end
  base_config
end

Vagrant.configure(2) do |config|
  vm_memory = ENV.fetch('SCF_VM_MEMORY', ENV.fetch('VM_MEMORY', 10 * 1024)).to_i
  vm_cpus = ENV.fetch('SCF_VM_CPUS', ENV.fetch('VM_CPUS', 4)).to_i
  vm_box_version = ENV.fetch('SCF_VM_BOX_VERSION', ENV.fetch('VM_BOX_VERSION', '2.0.17'))
  vm_registry_mirror = ENV.fetch('SCF_VM_REGISTRY_MIRROR', ENV.fetch('VM_REGISTRY_MIRROR', ''))

  HOME = "/home/vagrant"

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

    # https://github.com/mitchellh/vagrant/issues/351
    override.vm.synced_folder ".fissile/.bosh", "#{HOME}/.bosh", type: "nfs"
    override.vm.synced_folder ".", "#{HOME}/scf", type: "nfs"

    if ENV.include? custom_setup_scripts_env
      override.vm.synced_folder ENV.fetch(custom_setup_scripts_env),
        mounted_custom_setup_scripts, type: "nfs"
    end
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

    override.vm.synced_folder ".fissile/.bosh", "#{HOME}/.bosh", type: "nfs"
    override.vm.synced_folder ".", "#{HOME}/scf", type: "nfs"

    if ENV.include? custom_setup_scripts_env
      override.vm.synced_folder ENV.fetch(custom_setup_scripts_env),
        mounted_custom_setup_scripts, type: "nfs"
    end
  end

  # Adds the loop kernel module for loading on system startup, as well as loads it immediately.
  config.vm.provision :shell, privileged: true, inline: <<-SHELL
    echo "loop" > /etc/modules-load.d/loop.conf
    modprobe loop
  SHELL

  config.ssh.forward_env = ["FISSILE_COMPILATION_CACHE_CONFIG"]

  # Make sure we can pass FISSILE_* env variables from the host.
  config.vm.provision :shell, privileged: true, inline: <<-SHELL
    set -o errexit -o xtrace -o verbose
    echo "AcceptEnv FISSILE_*" | sudo tee -a /etc/ssh/sshd_config
    systemctl restart sshd.service
  SHELL

  config.vm.provision "shell", privileged: true, env: ENV.select { |e|
    %w(http_proxy https_proxy no_proxy).include? e.downcase
  }, path: "bin/common/write_proxy_vars_to_environment.sh"

  # Set up direnv so we can pick up fissile configuration.
  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    set -o errexit -o nounset
    mkdir -p ${HOME}/bin
    wget -O ${HOME}/bin/direnv --no-verbose \
      https://github.com/direnv/direnv/releases/download/v2.11.3/direnv.linux-amd64
    chmod a+x ${HOME}/bin/direnv
    echo 'eval "$(${HOME}/bin/direnv hook bash)"' >> ${HOME}/.bashrc
    ln -s -f ${HOME}/scf/bin/dev/vagrant-envrc ${HOME}/.envrc
    ${HOME}/bin/direnv allow ${HOME}
    ${HOME}/bin/direnv allow ${HOME}/scf
  SHELL

  # Install common and dev tools.
  config.vm.provision :shell, privileged: true, inline: <<-SHELL
    set -o errexit -o xtrace -o verbose
    export HOME="#{HOME}"
    export PATH="${PATH}:#{HOME}/bin"
    export SCF_BIN_DIR=/usr/local/bin

    if [ -n "#{vm_registry_mirror}" ]; then
      perl -p -i -e 's@^(DOCKER_OPTS=)"(.*)"@\\1"\\2 --registry-mirror=#{vm_registry_mirror}"@' /etc/sysconfig/docker
      # Docker has issues coming up on virtualbox; let it fail gracefully, if necessary.
      systemctl stop docker.service
      if ! systemctl restart docker.service ; then
        while [ "$(systemctl is-active docker.service)" != active ] ; do
          case "$(systemctl is-active docker.service)" in
            failed) systemctl reset-failed docker.service ;
                    systemctl restart docker.service ||: ;;
            *)      sleep 5                              ;;
          esac
        done
      fi
    fi

    cd "${HOME}/scf"
    bash ${HOME}/scf/bin/common/install_tools.sh
    direnv exec ${HOME}/scf/bin/dev/install_tools.sh

    # Enable RBAC for kube on vagrant boxes older than 2.0.10.
    if ! grep -q "KUBE_API_ARGS=.*--authorization-mode=RBAC" /etc/kubernetes/apiserver; then
      perl -p -i -e 's@^(KUBE_API_ARGS=)"(.*)"@\\1"\\2 --authorization-mode=RBAC"@' /etc/kubernetes/apiserver
      systemctl restart kube-apiserver
    fi
  SHELL

  # Ensure that kubelet is running correctly.
  config.vm.provision :shell, privileged: true, inline: <<-'SHELL'
    set -o errexit -o nounset -o xtrace
    if ! systemctl is-active kubelet.service ; then
      systemctl enable --now kubelet.service
    fi
  SHELL

  # Set up the storage class.
  config.vm.provision :shell, privileged: false, inline: <<-'SHELL'
    if ! kubectl get storageclass persistent 2>/dev/null ; then
      perl -p -e 's@storage.k8s.io/v1beta1@storage.k8s.io/v1@g' \
        "${HOME}/scf/src/uaa-fissile-release/kube-test/storage-class-host-path.yml" | \
      kubectl create -f -
    fi
  SHELL

  # Wait for the pods to be ready.
  config.vm.provision :shell, privileged: false, inline: <<-'SHELL'
    set -o errexit -o nounset -o xtrace
    for selector in k8s-app=kube-dns name=tiller ; do
      while ! kubectl get pods --namespace=kube-system --selector "${selector}" 2> /dev/null | grep -Eq '([0-9])/\1 *Running' ; do
        sleep 5
      done
    done
  SHELL

  config.vm.provision "shell", privileged: false,
                      env: {"FISSILE_COMPILATION_CACHE_CONFIG" => ENV["FISSILE_COMPILATION_CACHE_CONFIG"]},
                      inline: <<-SHELL
    set -o errexit
    echo 'if test -e /mnt/hgfs ; then /mnt/hgfs/scf/bin/dev/setup_vmware_mounts.sh ; fi' >> .profile

    echo 'export PATH="${PATH}:#{HOME}/scf/container-host-files/opt/scf/bin/"' >> .profile

    echo -e '\nexport HISTFILE="#{HOME}/scf/output/.bash_history"' >> .profile

    # Check that the cluster is reasonable.
    #{HOME}/scf/bin/dev/kube-ready-state-check.sh

    direnv exec #{HOME}/scf make -C #{HOME}/scf copy-compile-cache
  SHELL

  # Provision the custom config scripts and personal setup.
  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    set -o errexit

    if [ -d "#{mounted_custom_setup_scripts}/provision.d" ]; then
      scripts=($(find "#{mounted_custom_setup_scripts}/provision.d" -iname "*.sh" -executable -print | sort))
      for script in "${scripts[@]}"; do
        "${script}"
      done
    fi

    echo 'test -f "#{HOME}/scf/personal-setup" && . "#{HOME}/scf/personal-setup"' >> .profile

    echo -e "\n\nAll done - you can \e[1;96mvagrant ssh\e[0m\n\n"
  SHELL
end
