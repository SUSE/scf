# Helion Cloud Foundry

This is the repository that integrates all HCF components.

## Using port 80 on your host without root

You will need to change the host ports in the Vagrantfile from `80` to `8080`
and from `443` to `8443` and run the following:

```
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443
```

## Development on Ubuntu with VirtualBox

1. Install VirtualBox
1. Install Vagrant (version `1.7.4` minimum)
1. Install vagrant-reload plugin
 ```
 vagrant plugin install vagrant-reload
 ```
1. Bring it online
```
vagrant up --provider virtualbox
```
1. Run HCF in the vagrant box
 ```
 vagrant ssh
 cd ~/hcf
 make run
 ```

Before creating any VMs with Vagrant, run `THIS DIR`/bin/init-host-for-vagrant.sh. Otherwise vagrant (or others) won't see the mounted submodules.  This command can be run in parallel with `vagrant up`, but needs to complete before running `make vagrant-prep` on the VM.

This should prevent errors similar to "Package 'etcd' has a glob that resolves to an empty file list: `github.com/coreos/etcd/**/*`" while running `make vagrant-prep`  

## Development on OSX with VMWare Fusion

1. Install VMware Fusion 7
1. Get a license for VMware Fusion 7
 > From your HPE e-mail address, send an e-mail to hp@vmware.com,
 > with the subject "Fusion license request"

1. Install Vagrant (version `1.7.4` minimum)
1. Install vagrant-reload plugin
 ```bash
 vagrant plugin install vagrant-reload
 ```

1. Install the Vagrant Fusion provider
 ```bash
 vagrant plugin install vagrant-vmware-fusion
 ```

1. Setup the license for the Vagrant Fusion provider:
 - Download the license from our [wiki page](https://wiki.hpcloud.net/display/paas/MacBook+Laptop+and+License+Tracking#MacBookLaptopandLicenseTracking-VagrantFusionPlug-InLicense)
 - Install the license:
 ```bash
 vagrant plugin license vagrant-vmware-fusion /path/to/license.lic
 ```

1. Bring it online (make sure you don't have uncommited changes in any submodules - they will get clobbered)
 ```bash
 vagrant up --provider vmware_fusion
 ```

1. Run HCF in the vagrant box
 ```bash
 vagrant ssh
 cd ~/hcf
 make vagrant-prep  # Only needed once
 make run
 ```

## Development on Ubuntu with libvirt

1. Install Vagrant as detailed [here](https://www.virtualbox.org/wiki/Linux_Downloads)
1. Install dependencies
 ```bash
 sudo apt-get install libvirt-bin libvirt-dev qemu-utils qemu-kvm nfs-kernel-server
 ```

1. Allow non-root access to libvirt
 ```bash
 sudo usermod -G libvirtd -a YOUR_USER
 ```

1. Logout & Login
1. Install the `libvirt` plugin for Vagrant
 ```bash
 vagrant plugin install vagrant-libvirt
 ```

1. Install vagrant-reload plugin
 ```bash
 vagrant plugin install vagrant-reload
 ```

1. Bring it online (may fail a few times)
 ```bash
 vagrant up --provider libvirt
 ```

1. Run HCF in the vagrant box
 ```bash
 vagrant ssh
 cd ~/hcf
 make vagrant-prep  # Only needed once
 make run
 ```

## Windows

> Working on a Windows host is more complicated because of heavy usage of symlinks.
> Don't use this sort of setup unless you're comfortable with the extra complexity.
> Only the VirtualBox provider is supported on Windows!

1. Before you do anything, make sure you handle line endings correctly. Run this on the Windows host:

  ```bash
  git config --global core.autocrlf input
  ```

1. Clone this repository, but do not recursively update submodules - you need to do it in the Vagrant VM,
so symlinks are configured properly. For you do be able to clone everything
within the VM, you'll need an SSH key within the VM that's allowed on github.com

1. SSH to the vagrant box
  ```bash
  vagrant ssh
  ```

1. Setup symlinks and init submodules
  ```bash
  cd ~/hcf
  git config --global core.symlinks true
  git config core.symlinks true
  git submodule update --init --recursive
  ```

1. After all that you can continue with the normal stuff:
  ```bash
  cd ~/hcf
  make vagrant-prep  # Only needed once
  make run
  ```

## Makefile targets


### Vagrant VM Targets

name			| effect |
--------------- | ---- |
`run`			| Set up HCF on the current node (`bin/run.sh`) |
`stop`			| Stop HCF on the current node |
`vagrant-box`	| Build the vagrant box image via packer |
`vagrant-prep`	| Shortcut for building everything needed for `make run` |

### BOSH Release Targets

name				| effect |
------------------- | ----  |
`cf-release`		| `bosh create release` for `cf-release` |
`usb-release`		| `bosh create release` for `cf-usb-release` |
`diego-release`		| `bosh create release` for `diego-release` |
`etcd-release`		| `bosh create release` for `etcd-release` |
`garden-release`	| `bosh create release` for `garden-linux-release` |
`releases`			| Make all BOSH releases above |

### Fissile Build Targets

name			| effect |
--------------- | ---- |
`build`			| `make` + `make images` |
`compile-base`	| `fissile compilation build-base` |
`compile`		| `fissile dev compile` |
`images`		| `make bosh-image` + `make hcf-images` |
`image-base`	| `fissile images create-base` |
`bosh-images`	| `fissile dev create-images` |
`hcf-images`	| `make build` in docker-images |
`tag`			| Tag HCF images + bosh role images |
`publish`		| Publish HCF images + bosh role images to docker hub |
`terraform`		| Make `hcf-*.tar.gz` for distribution |

## Generating UCP service definitions

Assuming that the vagrant box for CF is running simply log into it with ssh and then run

```
docker run -it --rm \
  -v /home/vagrant/hcf:/home/vagrant/hcf \
  helioncf/hcf-pipeline-ruby-bosh \
  bash -l -c \
  "rbenv global 2.2.3 && /home/vagrant/hcf/bin/rm2ucp.rb /home/vagrant/hcf/container-host-files/etc/hcf/config/role-manifest.yml /home/vagrant/hcf/hcf-ucp.json"
```

This generates the `hcf-ucp.json` file containing the UCP service
definition for the current set of roles.

## Build dependencies

[![build-dependency-diagram](https://docs.google.com/drawings/d/130BRY-lElCWVEczOg4VtMGUSiGgJj8GBBw9Va5B-vLg/export/png)](https://docs.google.com/drawings/d/130BRY-lElCWVEczOg4VtMGUSiGgJj8GBBw9Va5B-vLg/edit?usp=sharing)
