# hcf-infrastructure

Build infrastructure for HCF 1.0

## Development

1. Get Vagrant (version `5.0.10` minimum)
2. Install vagrant-reload plugin
`vagrant plugin install vagrant-reload`
3. Make sure you don't have uncommited changes in any submodules - they will get clobbered
4. `vagrant up`

### Windows

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
