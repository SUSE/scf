# hcf-infrastructure

Build infrastructure for HCF 1.0

## Makefile-based development

```
export UBUNTU_IMAGE=ubuntu:14.04.2 (Default)
export CF_RELEASE=222
export WORK_DIR=$HOME/hpcloud/_work
export RELEASE_DIR=$HOME/hpcloud/cf-release-${CF_RELEASE}
export REGISTRY_HOST=helioncf
export BRANCH=develop
export REPOSITORY=hcf
export APP_VERSION=$APP_VERSION (Default)
# These next two are needed because `swift download ...` is currently broken
cp _work/configgin.tar.gz  $WORK_DIR/
cp  _work/fissile $WORK_DIR/
make CF_RELEASE=$CF_RELEASE WORK_DIR=$WORK_DIR RELEASE_DIR=$RELEASE_DIR REGISTRY_HOST=$REGISTRY_HOST BRANCH=$BRANCH REPOSITORY=$REPOSITORY 
```

## Development

1. Install VMware Fusion 7
1. Get a license for VMware Fusion 7
 > From your HPE e-mail address, send an e-mail to hp@vmware.com,
 > with the subject "Fusion license request"

1. Install Vagrant (version `1.7.4` minimum)
1. Install vagrant-reload plugin
 ```
 vagrant plugin install vagrant-reload
 ```

1. Install the Vagrant Fusion provider
 ```
 vagrant plugin install vagrant-vmware-fusion
 ```

1. Setup the license for the Vagrant Fusion provider:
 - Download the license from our [wiki page](https://wiki.hpcloud.net/display/paas/MacBook+Laptop+and+License+Tracking#MacBookLaptopandLicenseTracking-VagrantFusionPlug-InLicense)
 - Install the license:
 ```
 vagrant plugin license vagrant-vmware-fusion /path/to/license.lic
 ```

1. Bring it online (make sure you don't have uncommited changes in any submodules - they will get clobbered)
 ```
 vagrant up --provider vmware_fusion
 ```

1. Run HCF in the vagrant box
 ```
 vagrant ssh
 cd ~/hcf
 make run
 ```

### Windows (Currently not working, do not try this at home)

> Working on a Windows host is more complicated because of heavy usage of symlinks
> in the cf-release repository.
> Don't use this sort of setup unless you're comfortable with the extra complexity.

Before you do anything, make sure you handle line endings correctly:

```
git config --global core.autocrlf input
```

Do not recursively update submodules - you need to do it in the Vagrant VM,
so symlinks are configured properly.

```
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

## Build dependencies

[![build-dependency-diagram](https://docs.google.com/drawings/d/130BRY-lElCWVEczOg4VtMGUSiGgJj8GBBw9Va5B-vLg/export/png)](https://docs.google.com/drawings/d/130BRY-lElCWVEczOg4VtMGUSiGgJj8GBBw9Va5B-vLg/edit?usp=sharing)
