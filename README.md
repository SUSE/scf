# hcf-infrastructure

Build infrastructure for HCF 1.0

Before creating any VMs, do the following step in parallel with the
others in order to pull down all the cf-release and related
submodules. Otherwise vagrant (or others) won't see the mounted
submodules.

```bash
 cd src
 for dir in * ; do
   cd $dir
   # `git submodule update --init --recursive` failed sometimes - no idea why
   git submodule init
   git submodule update --recursive
   test -x scripts/update && bash -ex scripts/update
   cd ..
 done
``` 

This should prevent errors similar to "Package 'etcd' has a glob that resolves to an empty file list: github.com/coreos/etcd/**/*" while running `make vagrant-prep`  

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
sudo vagrant up --provider libvirt
```

## Windows (Currently not working, do not try this at home)

> Working on a Windows host is more complicated because of heavy usage of symlinks
> in the cf-release repository.
> Don't use this sort of setup unless you're comfortable with the extra complexity.

Before you do anything, make sure you handle line endings correctly:

```bash
git config --global core.autocrlf input
```

Do not recursively update submodules - you need to do it in the Vagrant VM,
so symlinks are configured properly.

```bash
# SSH to the vagrant box
vagrant ssh

# Setup symlinks
cd ~/hcf
git config --global core.symlinks true
git config core.symlinks true
git submodule update --init
git submodule foreach --recursive git config core.symlinks true

# For cf-release, run the update script
cd ./src/cf-release/
./scripts/update
```

Run `git config core.symlinks true` for the `hcf-infrastructure` repo.
Then, for all submodules: `git submodule foreach --recursive git config core.symlinks true`

## Makefile targets


### Vagrant VM Targets

name			| effect
--------------- | -
`run`			| Set up HCF on the current node (`bin/run.sh`)
`stop`			| Stop HCF on the current node
`vagrant-box`	| Build the vagrant box image via packer
`vagrant-prep`	| Shortcut for building everything needed for `make run`

### BOSH Release Targets
name				| effect
------------------- | -
`cf-release`		| `bosh create release` for `cf-release`
`usb-release`		| `bosh create release` for `cf-usb-release`
`diego-release`		| `bosh create release` for `diego-release`
`etcd-release`		| `bosh create release` for `etcd-release`
`garden-release`	| `bosh create release` for `garden-linux-release`
`releases`			| Make all BOSH releases above

### Fissile Build Targets
name			| effect
--------------- | -
`build`			| `make configs` + `make images`
`configs`		| `fissile dev config-gen`
`compile-base`	| `fissile compilation build-base`
`compile`		| `fissile dev compile`
`images`		| `make bosh-image` + `make hcf-images`
`image-base`	| `fissile images create-base`
`bosh-images`	| `fissile dev create-images`
`hcf-images`	| `make build` in docker-images
`tag`			| Tag HCF images + bosh role images
`publish`		| Publish HCF images + bosh role images to docker hub
`terraform`		| Make `hcf-*.tar.gz` for distribution

## Build dependencies

[![build-dependency-diagram](https://docs.google.com/drawings/d/130BRY-lElCWVEczOg4VtMGUSiGgJj8GBBw9Va5B-vLg/export/png)](https://docs.google.com/drawings/d/130BRY-lElCWVEczOg4VtMGUSiGgJj8GBBw9Va5B-vLg/edit?usp=sharing)
