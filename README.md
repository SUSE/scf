# SUSE Cloud Foundry

This repository integrates all SCF components.

# Preparing to Deploy SCF

## To Deploy SCF with Vagrant

_NOTE:_ These are the common instructions that are shared between all providers, some providers have different requirements, make sure that you read the appropriate section for your provider.

1. Install Vagrant (version 1.7.4 and higher).

2. Clone the repository and run the following command to allow Vagrant to interact with the mounted submodules:

  ```bash
  git clone git@github.com:suse/scf
  cd scf
  git submodule update --init --recursive
  ```

  __Important:__ Ensure you do not have uncommitted changes in any submodules.

3. Bring the VM online and `ssh` into it:

  ```bash
  # Replace X with one of: vmware_fusion, vmware_workstation, virtualbox
  vagrant up --provider X
  vagrant ssh
  ```

  __Note:__ The virtualbox provider is unstable and we've had many problems with SCF on it, try to use vmware when possible.

4. On the VM, navigate to the `~/scf` directory and run the `make vagrant-prep` command.

  ```bash
  cd scf
  make vagrant-prep
  ```

  __Note:__ You need to run this command only after initially creating the VM.

5. On the VM, start SCF using the `make run` command.

  ```bash
  make run
  ```

## To Deploy SCF on OS X Using VMWare Fusion

1. Install VMware Fusion 7 and Vagrant (version `1.7.4` and higher).

2. Install the Vagrant Fusion provider plugin:

  ```bash
  vagrant plugin install vagrant-vmware-fusion
  ```

**Note** `vagrant-vmware-fusion` version 4.0.9 or greater is required.

3. Get a Vagrant Fusion Provider license

  ```bash
  vagrant plugin license vagrant-vmware-fusion /path/to/license.lic
  ```

4. Follow the common instructions in the section above

## To Deploy SCF on Ubuntu Using `libvirt`

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

## To Deploy SCF on Fedora using `libvirt`

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

## Makefile targets

### Vagrant VM Targets

Name      | Effect |
--------------- | ---- |
`run`      | Set up SCF on the current node |
`stop`      | Stop SCF on the current node |
`vagrant-box`  | Build the Vagrant box image using `packer` |
`vagrant-prep`  | Shortcut for building everything needed for `make run` |

### BOSH Release Targets

Name        | Effect |
------------------- | ----  |
`binary-buildpack-release` | `bosh create release` for `binary-buildpack-release` |
`capi-release` | `bosh create release` for `capi-release` |
`cflinuxfs2-rootfs-release` | `bosh create release` for `cflinuxfs2-rootfs-release` |
`consul-release` | `bosh create release` for `consul-release` |
`diego-release` | `bosh create release` for `diego-release` |
`etcd-release` | `bosh create release` for `etcd-release` |
`garden-release` | `bosh create release` for `garden-release` |
`go-buildpack-release` | `bosh create release` for `go-buildpack-release` |
`grootfs-release` | `bosh create release` for `grootfs-release` |
`scf-release` | `bosh create release` for `scf-release` |
`java-buildpack-release` | `bosh create release` for `java-buildpack-release` |
`loggregator-release` | `bosh create release` for `loggregator-release` |
`mysql-release` | `bosh create release` for `mysql-release` |
`nats-release` | `bosh create release` for `nats-release` |
`nodejs-buildpack-release` | `bosh create release` for `nodejs-buildpack-release` |
`php-buildpack-release` | `bosh create release` for `php-buildpack-release` |
`python-buildpack-release` | `bosh create release` for `python-buildpack-release` |
`routing-release` | `bosh create release` for `routing-release` |
`ruby-buildpack-release` | `bosh create release` for `ruby-buildpack-release` |
`staticfile-buildpack-release` | `bosh create release` for `staticfile-buildpack-release` |
`uaa-release` | `bosh create release` for `uaa-release` |
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
`tag`           | Tag SCF images and bosh role images
`publish`       | Publish SCF images and bosh role images to Docker Hub

### Distribution Targets

Name    | Effect | Notes |
--------------- | ---- | --- |
`dist`    | Generate and package various setups |

## Development FAQ (on the vagrant box)

### Where do I find logs?

  1. To look at entrypoint logs, run the `docker logs <role-name>` command. To follow the logs, run the `docker logs -f <role-name>` command.

    __Note:__ For `bosh` roles, `monit` logs are displayed. For `docker` roles, the `stdout` and `stderr` from the entry point are displayed.

  2. All logs for all components can be found here on the Vagrant box in `~/.run/log`.

### How do I clear all data and begin anew without rebuilding everything?

  On the Vagrant box, run the following commands:

  ```bash
  cd ~/scf

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
  cd ~/scf

  # Stop gracefully.
  make stop

  # Delete all logs.
  sudo rm -rf ~/.run/log

  # Start everything.
  make run
  ```

### How do I run smoke and acceptance tests?

  On the Vagrant box, when `pod-status` reports all roles are running, enable `diego_docker` support with

  ```bash
  cf enable-feature-flag diego_docker
  ```

  and execute the following commands:

  ```bash
  kubectl create -n cf -f kube/bosh-task/smoke-tests.yml
  kubectl create -n cf -f kube/bosh-task/acceptance-tests-brain.yml
  kubectl create -n cf -f kube/bosh-task/acceptance-tests.yml
  ```


#### How do I run a subset of SCF acceptance tests?

  Deploy `acceptance-tests-brain` as above, but first modify the environment to include `INCLUDE=pattern` or
  `EXCLUDE=pattern`.  For example to run just `005_sso_test.sh` and `014_sso_authenticated_passthrough_test.sh`, you
  could add `INCLUDE` with a value of `sso`.

  It is also possible to run custom tests by mounting them at the `/tests` mountpoint inside the container.  The
  mounted tests will be combined with the bundled tests. However, to do so you will need to manually run it via docker.
  To exclude the bundled tests match against names starting with 3 digits followed by an underscore (as in,
  `EXCLUDE=\b\d{3}_`) or explicitly select only the mounted tests with `INCLUDE=^/tests/`.

#### How do I run a subset of Cloud Foundry acceptance tests?

  Deploy `acceptance-tests` after modifying the environment block to include `CATS_SUITES=-suite,+suite`.  Each suite is
  separated by a comma.  The modifiers apply until the next modifier is seen, and have the following meanings:

  Modifier | Meaning
  --- | ---
  `+` | Enable the following suites
  `-` | Disable the following suites
  `=` | Disable all suites, and enable the following suites

### `fissile` refuses to create images that already exist. How do I recreate images?

  On the Vagrant box, run the following commands:

  ```bash
  cd ~/scf

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

  * Run the `vagrant destroy -f && vagrant up` command and then run `make vagrant-prep run` on the Vagrant box.


### Can I target the cluster from the host using the `cf` CLI?

  You can target the cluster on the hardcoded `cf-dev.io` address assigned to a host-only network adapter.
  You can access any URL or endpoint that references this address from your host.


### How do I connect to the Cloud Foundry database?

  1. Use the role manifest to expose the port for the mysql proxy role

  2. The MySQL instance is exposed at `192.168.77.77:3306`.

  3. The default username is: `root`.

  4. You can find the default password in the `MYSQL_ADMIN_PASSWORD` environment variable in the `~/scf/bin/settings/settings.env` file on the Vagrant box.


### How do I add a new BOSH release to SCF?

  1. Add a Git submodule to the BOSH release in `./src`.

  2. Mention the new release in `.envrc`

  3. Edit the release parameters:

    a. Add new roles or change existing ones in `./container-host-files/etc/scf/config/role-manifest.yml`.

    b. Add exposed environment variables (`yaml path: /configuration/variables`).

    c. Add configuration templates (`yaml path: /configuration/templates` and `yaml path: /roles/*/configuration/templates`).

    d. Add defaults for your configuration settings to `~/scf/bin/settings/settings.env`.

    e. If you need any extra default certificates, add them to `~/scf/bin/settings/certs.env`.

    f. Add generation code for the certs to `~/scf/bin/generate-dev-certs.sh`.

  4. Add any opinions (static defaults) and dark opinions (configuration that must be set by user) to `./container-host-files/etc/scf/config/opinions.yml` and `./container-host-files/etc/scf/config/dark-opinions.yml`, respectively.

  5. Change the `./Makefile` so it builds the new release:

    a. Add a new target `<release-name>-release`.

    b. Add the new target as a dependency for `make releases`.

  6. Test the changes.

  7. Run the `make <release-name>-release compile images run` command.


### What does my dev cycle look like when I work on Component X?

  1. Make a change to component `X`, in its respective release (`X-release`).

  2. Run `make X-release compile images run` to build your changes and run them.


### How do I expose new settings via environment variables?

  1. Edit `./container-host-files/etc/scf/config/role-manifest.yml`:

    a. Add the new exposed environment variables (`yaml path: /configuration/variables`).

    b. Add or change configuration templates:

        i. `yaml path: /configuration/templates`

        ii. `yaml path: /roles/*/configuration/templates`

  2. Add defaults for your new settings in `~/scf/bin/settings/settings.env`.

  3. If you need any extra default certificates, add them to `~/scf/bin/dev-certs.env`.

  4. Add generation code for the certificates here: `~/scf/bin/generate-dev-certs.sh`

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

  This section describes how to bump all the submodules at the same
  time. This is the easiest way because we have scripts helping us
  here.

  1. On the host machine run

    ```bash
    bin/update-releases.sh <RELEASE>
    ```

    to bump to the specified release of CF. This pulls the information
    about compatible releases, creates clones and bumps them.

  2. Next up, we need the BOSH releases for the cloned and bumped submodules. Run

    ```bash
    bin/create-clone-releases.sh
    ```

    This command will place the log output for the individual releases
    into the sub directory `LOG/ccr`.

  3. With this done we can now compare the BOSH releases of originals
     and clones, telling us what properties have changed (added,
     removed, changed descriptions and values, ...).

     On the host machine run

    ```bash
    diff-releases.sh
    ```

    This command will place the log output and differences for the
    individual releases into the sub directory `LOG/dr`.

  4. Act on configuration changes:

    __Important:__ If you are not sure how to treat a configuration
    setting, discuss it with the SCF team.

    For any configuration changes discovered in step the previous
    step, you can do one of the following:

      * Keep the defaults in the new specification.

      * Add an opinion (static defaults) to `./container-host-files/etc/scf/config/opinions.yml`.

      * Add a template and an exposed environment variable to `./container-host-files/etc/scf/config/role-manifest.yml`.

    Define any secrets in the dark opinions file `./container-host-files/etc/scf/config/dark-opinions.yml` and expose them as environment variables.

      * If you need any extra default certificates, add them here: `~/scf/bin/dev-certs.env`.

      * Add generation code for the certificates here: `~/scf/bin/generate-dev-certs.sh`.

  5. Evaluate role changes:

    a. Consult the release notes of the new version of the release.

    b. If there are any role changes, discuss them with the SCF team, [follow steps 3 and 4 from this guide](#how-do-i-add-a-new-bosh-release-to-scf).

  6. Bump the real submodule:

    a. Bump the real submodule and begin testing.

    b. Remove the clone you used for the release.

  7. Test the release by running the `make <release-name>-release compile images run` command.


### Can I suspend or resume my vagrant VM?

  1. Run the `vagrant reload` command.

  2. Run the `make run` command.


### How do I develop an upstream PR?

  * If our submodules are close to the `HEAD` of upstream and no merge conflicts occur, follow [the steps described here](#if-im-working-on-component-x-how-does-my-dev-cycle-look-like).

  * If merge conflicts occur, or if the component is referenced as a submodule, and it is not compatible with the parent release, work with the SCF team to resolve the issue on a case-by-case basis.


### What is the difference between a BOSH role and a Docker role?

  * `fissile` generates `bosh` and `bosh-task` roles using BOSH releases while regular `Dockerfiles` create `docker` roles.

  * You can include both types of role in the role manifest, using the same run information.


### How can I add a Docker role to SCF?

  1. Name your new role.

  2. Create a directory named after your role in `./docker-images`.

  3. Create a `Dockerfile` in the new directory.

  4. Add your role to `role-manifest.yml`

  5. Test using the `make docker-images run` command.


## How do I publish SCF and BOSH images?

  1. Ensure that the Vagrant box is running.

  2. `ssh` into the Vagrant box.

  3. To tag the images into the selected registry and to push them, run the `make tag publish` command.

  4. This target uses the `make` variables listed below to construct the image names and tags:

    |Variable  |Meaning|Default|
    | ---    | ---  | ---  |
    |IMAGE_REGISTRY  | The name of the trusted registry to publish to (include a trailing slash)  | _empty_|
    |IMAGE_PREFIX  | The prefix to use for image names (must not be empty) |scf|
    |IMAGE_ORG  | The organization in the image registry |splatform|
    |BRANCH    | The tag to use for the images | _Current git branch_ |

  5. To publish to the standard trusted registry run the `make tag publish` command, for example:

    ```bash
    make tag publish IMAGE_REGISTRY=docker.example.com/
    ```
