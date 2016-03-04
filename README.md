# Helion Cloud Foundry

This is the repository that integrates all HCF components.

<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [Helion Cloud Foundry](#helion-cloud-foundry)
	- [Using port 80 on your host without root](#using-port-80-on-your-host-without-root)
	- [Development on Ubuntu with VirtualBox](#development-on-ubuntu-with-virtualbox)
	- [Development on OSX with VMWare Fusion](#development-on-osx-with-vmware-fusion)
	- [Development on Ubuntu with libvirt](#development-on-ubuntu-with-libvirt)
	- [Development on Windows with VirtualBox](#development-on-windows-with-virtualbox)
	- [Windows Cell Add-on](#windows-cell-addon)
	- [Makefile targets](#makefile-targets)
		- [Vagrant VM Targets](#vagrant-vm-targets)
		- [BOSH Release Targets](#bosh-release-targets)
		- [Fissile Build Targets](#fissile-build-targets)
	- [Development FAQ](#development-faq)
		- [Where do I find logs?](#where-do-i-find-logs)
		- [How do I clear all data for the cluster? (start fresh without rebuilding everything)](#how-do-i-clear-all-data-for-the-cluster-start-fresh-without-rebuilding-everything)
		- [How do I clear the logs?](#how-do-i-clear-the-logs)
		- [How do I recreate images? `fissile` refuses to create images that already exist.](#how-do-i-recreate-images-fissile-refuses-to-create-images-that-already-exist)
		- [My vagrant box is frozen. What do I do?](#my-vagrant-box-is-frozen-what-do-i-do)
		- [Can I use the `cf` CLI from the host?](#can-i-use-the-cf-cli-from-the-host)
		- [How do I connect to the Cloud Foundry database?](#how-do-i-connect-to-the-cloud-foundry-database)
		- [How do I add a new BOSH release to HCF?](#how-do-i-add-a-new-bosh-release-to-hcf)
		- [If I'm working on component `X`, how does my dev cycle look like?](#if-im-working-on-component-x-how-does-my-dev-cycle-look-like)
		- [How do I expose new settings via environment variables?](#how-do-i-expose-new-settings-via-environment-variables)
		- [How do I bump the submodules for the various releases?](#how-do-i-bump-the-submodules-for-the-various-releases)
		- [Can I suspend/resume my vagrant VM?](#can-i-suspendresume-my-vagrant-vm)
		- [What if I'm coding for an upstream PR?](#what-if-im-coding-for-an-upstream-pr)
	- [Generating UCP service definitions](#generating-ucp-service-definitions)
	- [Build dependencies](#build-dependencies)

<!-- /TOC -->

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
 
 make vagrant-prep # only after you first create the VM
 
 make run
 ```

Before creating any VMs with Vagrant, run `THIS DIR` /bin/init-host-for-vagrant.sh. Otherwise vagrant (or others) won't see the mounted submodules.  This command can be run in parallel with `vagrant up`, but needs to complete before running `make vagrant-prep` on the VM.

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

## Development on Windows with VirtualBox

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

## Windows Cell Add-on

[See Windows Cell README](windows/README.md)

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


## Development FAQ

### Where do I find logs?

 1. The easiest way to look at monit logs is `docker logs <ROLE_NAME>`.
 To follow the logs, use `docker logs -f <ROLE_NAME>`.
 2. All logs for all components can be found here (in the Vagrant box): `~/.run/log`

### How do I clear all data for the cluster? (start fresh without rebuilding everything)

  In the Vagrant box, you should run the following:
  ```bash
  cd ~/hcf
  # We're nuking everything, so no need to stop gracefully.
  docker rm -f $(docker ps -a -q)
  # Delete all data
  sudo rm -rf ~/.run/store
  # Start everything
  make run
  ```

### How do I clear the logs?

  In the Vagrant box, you should run the following:
  ```bash
  cd ~/hcf
  # Stop gracefully.
  make stop
  # Delete all logs
  sudo rm -rf ~/.run/log
  # Start everything
  make run
  ```

### How do I recreate images? `fissile` refuses to create images that already exist.

  In the Vagrant box, you should run the following:
  ```bash
  cd ~/hcf
  # Stop gracefully.
  make stop
  # Delete all fissile images
  docker rmi $(fissile dev lr)
  # Re-create your images then run
  make images run
  ```

### My vagrant box is frozen. What do I do?

  1. If you have an SSH connection that's frozen, type in: `~.<ENTER>`
  2. Then, do: `vagrant reload`
  3. If this hangs use: `vagrant halt && vagrant reload`
  4. If that hangs, manually stop the virtual machine, then run: `vagrant reload`
  5. Last resort: `vagrant destroy -f && vagrant up`
  6. Finally, you run `make run` inside the vagrant box to bring everything back up.

### Can I use the `cf` CLI from the host?

  Yes, you can. The Vagrant box will always expose the Cloud Foundry endpoints on the
  `192.168.77.77` IP address.

  This is assigned to a host-only network adapter, so
  any URL/endpoint that references this address can be accessed from your host.  

### How do I connect to the Cloud Foundry database?

  For your convenience, we expose the MySQL instance on `192.168.77.77:3306`.

  The default username is: `root`. Default password can be found in the following
  environment variables file (path in the Vagrant box): `~/hcf/bin/dev-settings.env`.
  Look for the `MYSQL_ADMIN_PASSWORD` variable.

### How do I add a new BOSH release to HCF?

  1. Add a git submodule to the BOSH release in `./src`
  2. Mention the new release in `./bin/.fissilerc`
  3. Change `./container-host-files/etc/hcf/config/role-manifest.yml`
    - Add new roles or change existing ones
    - Add exposed environment variables (`yaml path: /configuration/variables`)
    - Add configuration templates (`yaml path: /configuration/templates` and `yaml path: /roles/*/configuration/templates`)
    - Add defaults for your configuration settings in `~/hcf/bin/dev-settings.env`
    - If you need any extra default certs, add them here: `~/hcf/bin/dev-settings.env`.
    Also make sure to add generation code for the certs here: `~/hcf/bin/generate-dev-certs.sh`
  4. Add any opinions (static defaults) and dark opinions (configuration that must be set by user)
  to `./container-host-files/etc/hcf/config/opinions.yml` and `./container-host-files/etc/hcf/config/dark-opinions.yml`
  respectively
  5. Change the `./Makefile` so it builds the new release
    - Add a new target `<RELEASE_NAME>-release`
    - Add the new target as a dependency for `make releases`
  6. Test, test and test
    - `make <RELEASE_NAME>-release compile images run`
    - repeat

### If I'm working on component `X`, how does my dev cycle look like?

  1. Make a change to component `X`, in its respective release (`X-release`)
  2. Run `make X-release compile images run` to build your changes and run them

### How do I expose new settings via environment variables?

  In `./container-host-files/etc/hcf/config/role-manifest.yml`:
  1. Add your new exposed environment variables (`yaml path: /configuration/variables`)
  2. Add or change configuration templates
    - `yaml path: /configuration/templates`
    - `yaml path: /roles/*/configuration/templates`
  3. Add defaults for your new settings in `~/hcf/bin/dev-settings.env`
  4. If you need any extra default certs, add them here: `~/hcf/bin/dev-certs.env`
  Also make sure to add generation code for the certs here: `~/hcf/bin/generate-dev-certs.sh`
  5. At this point, you'll need to rebuild the role images that need this new setting:

    ```bash
    docker stop <ROLE>
    docker rmi -f fissile-<ROLE>:<TAB_FOR_COMPLETION>
    make images run
    ```

    If you don't know which roles need your new setting, you can use this catch-all:

    ```bash
    make stop
    docker rmi -f $(fissile dev lr)
    make images run
    ```

### How do I bump the submodules for the various releases?

  > Please note that this may be lengthy process, since it involves cloning
  > and building a release.

  The following example is provided for `cf-release`. The same steps should be
  followed for other releases as well.

  1. Locally clone the repo you want to bump

  ```bash
  # IMPORTANT: do this on the HOST
  git clone src/cf-release/ ./src/cf-release-clone --recursive
  ```

  2. Bump the clone to the version you want

  ```bash
  # IMPORTANT: still on the HOST
  git checkout v217
  git submodule update --init --recursive --force
  ```

  3. Create a release for the cloned repo

  ```bash
  # IMPORTANT: from this point forward, do everything in the Vagrant box
  cd ~/hcf
  ./bin/create-release src/cf-release-clone cf
  ```

  4. Run the config diff

  ```bash
  FISSILE_RELEASE='' fissile dev config-diff --release ~/hcf/src/cf-release --release ~/hcf/src/cf-release-clone  
  ```

  5. Act on config changes

  > If you're not sure how to treat a configuration setting, discuss it with the HCF team.

  For any configuration changes discovered in step **4**, you can do one of the following:

   - Keep the defaults in the new spec
   - Add an opinion (static defaults) to `./container-host-files/etc/hcf/config/opinions.yml`
   - Add a template and an exposed environment variable to `./container-host-files/etc/hcf/config/role-manifest.yml`

  For any secrets, make sure to define them in the dark opinions file `./container-host-files/etc/hcf/config/dark-opinions.yml` and expose them as an environment variable

   - If you need any extra default certs, add them here: `~/hcf/bin/dev-certs.env`.
   - Also make sure to add generation code for the certs here: `~/hcf/bin/generate-dev-certs.sh`

  6. Role changes

  You must consult the release notes for the new version of the release.

  If there are any role changes, please discuss them with the HCF team,
  then follow steps **3** and **4** from [here](#how-do-i-add-a-new-bosh-release-to-hcf).

  7. Bump real submodule

  At this point you can bump the 'real' submodule and start testing.

  The clone you used for the release can be removed.

  8. Test, test and test
    - `make <RELEASE_NAME>-release compile images run`
    - repeat

### Can I suspend/resume my vagrant VM?

  Yes, to get it back up you have to `vagrant reload` and
  and then `make run` inside to bring everything back up.

### What if I'm coding for an upstream PR?

  There are a couple of scenarios:
  1. If our submodules are close to the HEAD of upstream,
  so there are no merge conflicts that you have to deal with.

  > In this case, you can use the steps described [here](#if-im-working-on-component-x-how-does-my-dev-cycle-look-like)
  > to do your development.

  2. If there are merge conflicts, or the component is referenced as a submodule,
  and it's not compatible with the parent release.

  > We don't have a good story for this at the moment, since it assumes there are
  > unresolved incompatibilities. These cases will have to be resolved on an ad-hoc
  > basis.


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
