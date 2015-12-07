# hcf-infrastructure

Build infrastructure for HCF 1.0

## Development

1. Install VMware Fusion 7
1. Get a license for VMware Fusion 7
 > From your HPE e-mail address, send an e-mail to hp@vmware.com,
 > with the subject "Fusion license request"

1. Install Vagrant (version `5.0.10` minimum)
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
