# Helion Cloud Foundry

This repository integrates all HCF components.

# Preparing to Deploy HCF

__Note:__ You can run the Windows Cell Add-On on a variety of systems within a Vagrant VM. For more information, see [To Deploy HCF on Windows Using VirtualBox](#to-deploy-hcf-on-windows-using-virtualbox).

## To Use Port 80 on Your Host Without `root` Privileges

```bash
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443
```

## To Deploy HCF with Vagrant

_NOTE:_ This is the common instructions that are shared between all providers, some providers have different requirements, make sure that you read the appropriate section for your provider.

1. Install Vagrant (version 1.7.4 and higher).

2. Clone the repository and run the following command to allow Vagrant to interact with the mounted submodules:

  ```bash
  git clone git@github.com:hpcloud/hcf
  cd hcf
  git submodule update --init --recursive
  ```

  __Important:__ Ensure you do not have uncommitted changes in any submodules.

3. Bring the VM online and `ssh` into it:

  ```bash
  # Replace X with one of: vmware_fusion, vmware_workstation, virtualbox
  vagrant up --provider X
  vagrant ssh
  ```

  __Note:__ The virtualbox provider is unstable and we've had many problems with HCF on it, try to use vmware when possible.

4. On the VM, navigate to the `~/hcf` directory and run the `make vagrant-prep` command.

  ```bash
  cd hcf
  make vagrant-prep
  ```

  __Note:__ You need to run this command only after initially creating the VM.

5. On the VM, start HCF using the `make run` command.

  ```bash
  make run
  ```

## To Deploy HCF on OS X Using VMWare Fusion

1. Install VMware Fusion 7 and Vagrant (version `1.7.4` and higher).

  __Note:__ To get a license for VMware Fusion 7, use your HPE email address to send a message to hp@vmware.com with the subject `Fusion license request`.

2. Install the Vagrant Fusion provider plugin:

  ```bash
  vagrant plugin install vagrant-vmware-fusion
  ```

**Note** `vagrant-vmware-fusion` version 4.0.9 or greater is required.

3. [Download the Vagrant Fusion Provider license](https://wiki.hpcloud.net/display/paas/MacBook+Laptop+and+License+Tracking#MacBookLaptopandLicenseTracking-VagrantFusionPlug-InLicense) and install it:

  ```bash
  vagrant plugin license vagrant-vmware-fusion /path/to/license.lic
  ```

4. Follow the common instructions in the section above

## To Deploy HCF on Ubuntu Using `libvirt`

1. Install Vagrant (version `1.7.4` and higher) and the `libvirt` dependencies and allow non-`root` access to `libvirt`:

  ```bash
  sudo apt-get install libvirt-bin libvirt-dev qemu-utils qemu-kvm nfs-kernel-server
  ```

2. Allow non-`root` access to `libvirt`:

  ```bash
  sudo usermod -G libvirtd -a <username>
  ```

3. Log out, log in, and then install the `libvirt` plugin:

  ```bash
  vagrant plugin install vagrant-libvirt
  ```

4. Follow the common instructions above

  __Important:__ The VM may not come online during your first attempt.

## To Deploy HCF on Fedora using `libvirt`

1. Install Vagrant (version `1.7.4` and higher) and enable NFS over UDP:

  ```bash
  sudo firewall-cmd --zone FedoraWorkstation --change-interface vboxnet0
  sudo firewall-cmd --permanent --zone FedoraWorkstation --add-service nfs
  sudo firewall-cmd --permanent --zone FedoraWorkstation --add-service rpc-bind
  sudo firewall-cmd --permanent --zone FedoraWorkstation --add-service mountd
  sudo firewall-cmd --permanent --zone FedoraWorkstation --add-port 2049/udp
  sudo firewall-cmd --reload
  sudo systemctl enable nfs-server.service
  sudo systemctl start nfs-server.service
  ```

2. Install `libvirt` dependencies, allow non-`root` access to `libvirt`, and create a group for the `libvirt` user:

  ```bash
  sudo dnf install libvirt-daemon-kvm libvirt-devel
  sudo usermod -G libvirt -a <username>
  newgrp libvirt
  ```

3. Install `fog-libvirt` 0.0.3 and the `libvirt` plugins:

  ```bash
  # Workaround for https://github.com/fog/fog-libvirt/issues/16
  vagrant plugin install --plugin-version 0.0.3 fog-libvirt
  vagrant plugin install vagrant-libvirt
  ```

4. To set the `libvert` daemon user to your username/group, edit `/etc/libvirt/qemu.conf` as follows:

  ```
  user = "<username>"
  group = "<username>"
  ```

5. Follow the common instructions above

  __Important:__ The VM may not come online during your first attempt.

## To Deploy HCF on Windows Using VirtualBox

__Important:__ Working on a Windows host is __significantly more complicated__ because of heavy usage of symlinks. On Windows, only the VirtualBox provider is supported.

1. Ensure that line endings are handled correctly.

  ```bash
  git config --global core.autocrlf input
  ```

2. Clone the repository, bring the VM online, and `ssh` into it:

  __Important:__ Do not recursively update submodules. To ensure that symlinks are configured properly, you need to do this on the Vagrant VM. To be able to clone everything within the VM, you will need an `ssh` key within the VM allowed on GitHub.

  ```bash
  vagrant up --provider virtualbox
  vagrant ssh
  ```

3. Configure symlinks and initialize submodules:

  ```bash
  cd ~/hcf
  git config --global core.symlinks true
  git config core.symlinks true
  git submodule update --init --recursive
  ```

4. On the VM, navigate to the `~/hcf` directory and run the `make vagrant-prep` command.

  ```bash
  cd hcf
  make vagrant-prep
  ```

  __Note:__ You need to run this command only after initially creating the VM.

5. On the VM, start HCF

  ```bash
  make run
  ```

6. For the Windows Cell Add-On, see the [Windows Cell Readme](windows/README.md).

  __Important:__ You can run the Windows Cell Add-On on a variety of systems within a Vagrant VM.

## To Deploy HCF on Amazon AWS Using Terraform

* Pick a target, e.g. `aws-spot-dist` and run `make aws-spot-dist ENV_DIR=$PWD/bin/settings-dev`
  to generate the archive populated with development defaults and secrets.

* Extract the newly created .zip file to a temporary working dir:
```bash
mkdir /tmp/hcf-aws
cd /tmp/hcf-aws
unzip $OLDPWD/aws-???.zip
cd aws
```

* Follow the instructions in README-aws.md

## Makefile targets

### Vagrant VM Targets

Name      | Effect |
--------------- | ---- |
`run`      | Set up HCF on the current node (`bin/run.sh`) |
`stop`      | Stop HCF on the current node |
`vagrant-box`  | Build the Vagrant box image using `packer` |
`vagrant-prep`  | Shortcut for building everything needed for `make run` |

### BOSH Release Targets

Name        | Effect |
------------------- | ----  |
`cf-release`    | `bosh create release` for `cf-release` |
`usb-release`    | `bosh create release` for `cf-usb-release` |
`diego-release`    | `bosh create release` for `diego-release` |
`etcd-release`    | `bosh create release` for `etcd-release` |
`garden-release`  | `bosh create release` for `garden-linux-release` |
`cf-mysql-release` | `bosh create release` for `cf-mysql-release` |
`hcf-sso-release` | `bosh create release` for `hcf-sso-release` |
`hcf-versions-release` | `bosh create release` for `hcf-versions-release` |
`cflinuxfs2-rootfs-release`  | `bosh create release` for `cflinuxfs2-rootfs-release` |
`releases`      | Make all of the BOSH releases above |

### Fissile Build Targets

Name            | Effect
--------------- | ----
`build`         | `make compile` + `make images`
`compile-base`  | `fissile build layer compilation`
`compile`       | `fissile build packages`
`images`        | `make bosh-images` + `make docker-images`
`image-base`    | `fissile build layer stemcell`
`bosh-images`   | `fissile build images`
`docker-images` | `docker build` in each dir in `./docker-images`
`tag`           | Tag HCF images and bosh role images
`publish`       | Publish HCF images and bosh role images to Docker Hub
`hcp`           | Generate HCP service definitions
`mpc`           | Generate Terraform MPC definitions for a single-node microcloud
`aws`           | Generate Terraform AWS definitions for a single-node microcloud

### Distribution Targets

Name    | Effect | Notes |
--------------- | ---- | --- |
`dist`    | Generate and package various setups |
`mpc-dist`  | Generate and package Terraform MPC definitions for a single-node microcloud |
`aws-dist`  | Generate and package Terraform AWS definitions for a single-node microcloud |
`aws-proxy-dist`  | Generate and package Terraform AWS definitions for a proxied microcloud |
`aws-spot-dist`  | Generate and package Terraform AWS definitions for a single-node microcloud using a spot instance |
`aws-spot-proxy-dist`  | Generate and package Terraform AWS definitions for a proxied microcloud using spot instances |

## Development FAQ

### Where do I find logs?

  1. To look at entrypoint logs, run the `docker logs <role-name>` command. To follow the logs, run the `docker logs -f <role-name>` command.

    __Note:__ For `bosh` roles, `monit` logs are displayed. For `docker` roles, the `stdout` and `stderr` from the entry point are displayed.

  2. All logs for all components can be found here on the Vagrant box in `~/.run/log`.

### How do I clear all data and begin anew without rebuilding everything?

  On the Vagrant box, run the following commands:

  ```bash
  cd ~/hcf

  # (There is no need for a graceful stop.)
  docker rm -f $(docker ps -a -q)

  # Delete all data.
  sudo rm -rf ~/.run/store

  # Start everything.
  make run
  ```

### How do I clear the logs?

  On the Vagrant box, run the following commands:

  ```bash
  cd ~/hcf

  # Stop gracefully.
  make stop

  # Delete all logs.
  sudo rm -rf ~/.run/log

  # Start everything.
  make run
  ```

### How do I run smoke and acceptance tests?

  On the Vagrant box, when `hcf-status` reports all roles are running, execute the following commands:

  ```bash
  run-role.sh /home/vagrant/hcf/bin/settings-dev/ smoke-tests
  run-role.sh /home/vagrant/hcf/bin/settings-dev/ acceptance-tests
  ```

### `fissile` refuses to create images that already exist. How do I recreate images?

  On the Vagrant box, run the following commands:

  ```bash
  cd ~/hcf

  # Stop gracefully.
  make stop

  # Delete all fissile images.
  docker rmi $(fissile show image)

  # Re-create the images and then run them.
  make images run
  ```

### My vagrant box is frozen. What can I do?

  Try each of the following solutions sequentially:

  * Run the `~. && vagrant reload` command.

  * Run `vagrant halt && vagrant reload` command.

  * Manually stop the virtual machine and then run the `vagrant reload` command.

  * Run the `vagrant destroy -f && vagrant up` command and then run `make run` on the Vagrant box.


### Can I target the cluster from the host using the `cf` CLI?

  You can target the cluster on the hardcoded `192.168.77.77` address assigned to a host-only network adapter.
  You can access any URL or endpoint that references this address from your host.


### How do I connect to the Cloud Foundry database?

  1. The MySQL instance is exposed at `192.168.77.77:3306`.

  2. The default username is: `root`.

  3. You can find the default password in the `MYSQL_ADMIN_PASSWORD` environment variable in the `~/hcf/bin/settings-dev/settings.env` file on the Vagrant box.


### How do I add a new BOSH release to HCF?

  1. Add a Git submodule to the BOSH release in `./src`.

  2. Mention the new release in `./bin/.fissilerc`

  3. Edit the release parameters:

    a. Add new roles or change existing ones in `./container-host-files/etc/hcf/config/role-manifest.yml`.

    b. Add exposed environment variables (`yaml path: /configuration/variables`).

    c. Add configuration templates (`yaml path: /configuration/templates` and `yaml path: /roles/*/configuration/templates`).

    d. Add defaults for your configuration settings to `~/hcf/bin/settings-dev/settings.env`.

    e. If you need any extra default certificates, add them to `~/hcf/bin/settings-dev/certs.env`.

    f. Add generation code for the certs to `~/hcf/bin/generate-dev-certs.sh`.

  4. Add any opinions (static defaults) and dark opinions (configuration that must be set by user) to `./container-host-files/etc/hcf/config/opinions.yml` and `./container-host-files/etc/hcf/config/dark-opinions.yml`, respectively.

  5. Change the `./Makefile` so it builds the new release:

    a. Add a new target `<release-name>-release`.

    b. Add the new target as a dependency for `make releases`.

  6. Test the changes.

  7. Run the `make <release-name>-release compile images run` command.


### What does my dev cycle look like when I work on Component X?

  1. Make a change to component `X`, in its respective release (`X-release`).

  2. Run `make X-release compile images run` to build your changes and run them.


### How do I expose new settings via environment variables?

  1. Edit `./container-host-files/etc/hcf/config/role-manifest.yml`:

    a. Add the new exposed environment variables (`yaml path: /configuration/variables`).

    b. Add or change configuration templates:

        i. `yaml path: /configuration/templates`

        ii. `yaml path: /roles/*/configuration/templates`

  2. Add defaults for your new settings in `~/hcf/bin/settings-dev/settings.env`.

  3. If you need any extra default certificates, add them to `~/hcf/bin/dev-certs.env`.

  4. Add generation code for the certificates here: `~/hcf/bin/generate-dev-certs.sh`

  5. Rebuild the role images that need this new setting:

    ```bash
    docker stop <role>
    docker rmi -f fissile-<role>:<tab-for-completion>
    make images run
    ```

    __Tip:__ If you do not know which roles require your new settings, you can use the following catch-all:

    ```bash
    make stop
    docker rmi -f $(fissile show image)
    make images run
    ```

### How do I bump the submodules for the various releases?

  __Note:__ Because this process involves cloning and building a release, it may take a long time.

  Cloud Foundry maintains a [compatibility spreadsheet](https://github.com/cloudfoundry-incubator/diego-cf-compatibility)
  for `cf-release`, `diego-release`, `etcd-release`, and `garden-linux-release`. If you are bumping
  all of those modules simultaneously, you can run `bin/update-cf-release.sh <RELEASE>` and skip steps
  1 and 2 in the example:

  The following example is for `cf-release`. You can follow the same steps for other releases.

  1. On the host machine, clone the repository that you want to bump:

    ```bash
  git clone src/cf-release/ ./src/cf-release-clone --recursive
    ```

  2. On the host, bump the clone to the desired version:

    ```bash
    git checkout v217
    git submodule update --init --recursive --force
    ```

  3. Create a release for the cloned repository:

    __Important:__ From this point on, perform all actions on the Vagrant box.

    ```bash
    cd ~/hcf
    ./bin/create-release.sh src/cf-release-clone cf
    ```

  4. Run the `config-diff` command:

    ```bash
    FISSILE_RELEASE='' fissile diff --release ${HOME}/hcf/src/cf-release,${HOME}/hcf/src/cf-release-clone
    ```

  5. Act on configuration changes:

    __Important:__ If you are not sure how to treat a configuration setting, discuss it with the HCF team.

    For any configuration changes discovered in step the previous step, you can do one of the following:

      * Keep the defaults in the new specification.

      * Add an opinion (static defaults) to `./container-host-files/etc/hcf/config/opinions.yml`.

      * Add a template and an exposed environment variable to `./container-host-files/etc/hcf/config/role-manifest.yml`.

    Define any secrets in the dark opinions file `./container-host-files/etc/hcf/config/dark-opinions.yml` and expose them as environment variables.

      * If you need any extra default certificates, add them here: `~/hcf/bin/dev-certs.env`.

      * Add generation code for the certificates here: `~/hcf/bin/generate-dev-certs.sh`.

  6. Evaluate role changes:

    a. Consult the release notes of the new version of the release.

  b. If there are any role changes, discuss them with the HCF team, [follow steps 3 and 4 from this guide](#how-do-i-add-a-new-bosh-release-to-hcf).

  7. Bump the real submodule:

    a. Bump the real submodule and begin testing.

    b. Remove the clone you used for the release.

  8. Test the release by running the `make <release-name>-release compile images run` command.


### Can I suspend or resume my vagrant VM?

  1. Run the `vagrant reload` command.

  2. Run the `make run` command.


### How do I develop an upstream PR?

  * If our submodules are close to the `HEAD` of upstream and no merge conflicts occur, follow [the steps described here](#if-im-working-on-component-x-how-does-my-dev-cycle-look-like).

  * If merge conflicts occur, or if the component is referenced as a submodule, and it is not compatible with the parent release, work with the HCF team to resolve the issue on a case-by-case basis.


### What is the difference between a BOSH role and a Docker role?

  * `fissile` generates `bosh` and `bosh-task` roles using BOSH releases while regular `Dockerfiles` create `docker` roles.

  * You can include both types of role in the role manifest, using the same run information.


### How can I add a Docker role to HCF?

  1. Name your new role.

  2. Create a directory named after your role in `./docker-images`.

  3. Create a `Dockerfile` in the new directory.

  4. Add your role to `role-manifest.yml`

  5. Test using the `make docker-images run` command.


## How do I publish HCF and BOSH images?

  1. Ensure that the Vagrant box is running.

  2. `ssh` into the Vagrant box.

  3. To tag the images into the selected registry and to push them, run the `make tag publish` command.

  4. This target uses the `make` variables listed below to construct the image names and tags:

    |Variable  |Meaning|Default|
    | ---    | ---  | ---  |
    |IMAGE_REGISTRY  | The name of the trusted registry to publish to (include a trailing slash)  | _empty_|
    |IMAGE_PREFIX  | The prefix to use for image names (must not be empty) |hcf|
    |IMAGE_ORG  | The organization in the image registry |helioncf|
    |BRANCH    | The tag to use for the images | _Current git branch_ |

  5. To publish to the standard trusted registry run the `make tag publish` command, for example:

    ```bash
    make tag publish IMAGE_REGISTRY=docker.helion.lol/
    ```


## How do I generate HCP service definitions?

  1. Ensure that the Vagrant box is running.

  2. `ssh` into the Vagrant box.

  3. To generate the `hcf-hcp.json` file that contains the HCP service definition for the current set of roles, run the `make hcp` command.

    __Note:__ This target takes the same `make` variables as the `tag` and `publish` targets.

  You can also read a step by step tutorial of running [HCF on HCP](hcp/README.md) using Vagrant.

## How do I generate Terraform MPC service definitions?

  1. Ensure that the Vagrant box is running.

  2. `ssh` into the Vagrant box.

  3. To generate the `hcf.tf` file that contains the Terraform definitions for an MPC_based, single-node microcloud, run the `make mpc` command.

    __Note:__ This target takes the same `make` variables as the `tag` and `publish` targets.


## How do I test a new version of configgin

1. Ensure that the Vagrant box is running.

2. `ssh` into the Vagrant box.

3. Build new configgin binary and install it into all role images

    `configgin` is installed as a binary in `~/tools/configgin.tgz`. In order to test a new version you have to install a new build in that location and recreate first the base image, and then all role images.

    In the `docker rmi` command below use tab-completion to also delete the image tagged with a version string:

    ```bash
    git clone git@github.com:hpcloud/hcf-configgin.git
    cd hcf-configgin/
    make dist
    cp output/configgin*.tgz ~/tools/configgin.tgz
    docker rmi -f $(fissile show image) fissile-role-base fissile-role-base:<TAB>
    make image-base images
    ```


## Build Dependencies

[![build-dependency-diagram](https://docs.google.com/drawings/d/130BRY-lElCWVEczOg4VtMGUSiGgJj8GBBw9Va5B-vLg/export/png)](https://docs.google.com/drawings/d/130BRY-lElCWVEczOg4VtMGUSiGgJj8GBBw9Va5B-vLg/edit?usp=sharing)
