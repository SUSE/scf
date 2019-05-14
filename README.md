# SUSE Cloud Foundry

SUSE Cloud Foundry (SCF) is a [Cloud Foundry](https://www.cloudfoundry.org)
distribution based on the open source version but with several very key
differences:

* Uses [fissile](https://github.com/suse/fissile) to containerize the CF components, for running on top of Kubernetes (and Docker)
* CF Components run on an SUSE Linux Enterprise Stemcell
* CF Apps optionally can run on a preview of the SUSE Linux Enterprise Stack (rootfs + buildpacks)

# Disclaimer

Fissile has been around for a few years now and its containerization technology
is fairly stable; however deploying directly to kubernetes is relatively new, as is the
SLE stack and stemcell. This means that things are liable to break as we continue
development. Specifically links and where things are hosted are still in flux and will most
likely break.

For development testing we've mainly been targeting the following so they should
be a known working quantity:

| OS             | Virtualization |
|----------------|----------------|
| SLE 15         | Libvirt        |
| Mac OSX Sierra | VirtualBox     |

For more production-like deploys we've been targetting baremetal Kubernetes 1.6.1 (using only 1.5 features)
though these deploys currently require the adventurer to be able to debug and problem solve
which takes knowledge of the components this repo brings together currently.

Table of Contents
=================

   * [SUSE Cloud Foundry](#suse-cloud-foundry)
   * [Disclaimer](#disclaimer)
   * [Table of Contents](#table-of-contents)
   * [Deploying SCF on Vagrant](#deploying-scf-on-vagrant)
      * [Requirements](#requirements)
      * [Deploying](#deploying)
      * [Usage](#usage)
      * [Troubleshooting](#troubleshooting)
   * [Deploying SCF on Kubernetes](#deploying-scf-on-kubernetes)
      * [Makefile targets](#makefile-targets)
         * [Vagrant VM Targets](#vagrant-vm-targets)
   * [Deployment Customizations](#deployment-customizations)
     * [Customize The Application Domain](#customize-the-application-domain)
   * [Development FAQ](#development-faq)
      * [Where do I find logs?](#where-do-i-find-logs)
      * [How do I clear all data and begin anew without rebuilding everything?](#how-do-i-clear-all-data-and-begin-anew-without-rebuilding-everything)
      * [How do I tear down a cluster on a cloud provider?](#how-do-i-tear-down-a-cluster-on-a-cloud-provider)
      * [How do I run smoke and acceptance tests?](#how-do-i-run-smoke-and-acceptance-tests)
         * [How do I run a subset of SCF acceptance tests?](#how-do-i-run-a-subset-of-scf-acceptance-tests)
         * [How do I run a subset of Cloud Foundry acceptance tests?](#how-do-i-run-a-subset-of-cloud-foundry-acceptance-tests)
      * [fissile refuses to create images that already exist. How do I recreate images?](#fissile-refuses-to-create-images-that-already-exist-how-do-i-recreate-images)
      * [My vagrant box is frozen. What can I do?](#my-vagrant-box-is-frozen-what-can-i-do)
      * [Can I target the cluster from the host using the cf CLI?](#can-i-target-the-cluster-from-the-host-using-the-cf-cli)
      * [How do I connect to the Cloud Foundry database?](#how-do-i-connect-to-the-cloud-foundry-database)
      * [How do I add a new BOSH release to SCF?](#how-do-i-add-a-new-bosh-release-to-scf)
      * [What does my dev cycle look like when I work on Component X?](#what-does-my-dev-cycle-look-like-when-i-work-on-component-x)
      * [How do I expose new settings via environment variables?](#how-do-i-expose-new-settings-via-environment-variables)
      * [How do I bump the submodules for the various releases?](#how-do-i-bump-the-submodules-for-the-various-releases)
      * [Can I suspend or resume my vagrant VM?](#can-i-suspend-or-resume-my-vagrant-vm)
      * [How do I develop an upstream PR?](#how-do-i-develop-an-upstream-pr)
      * [How do I publish SCF and BOSH images?](#how-do-i-publish-scf-and-bosh-images)
      * [How do I use an authenticated registry for my Docker images?](#how-do-i-use-an-authenticated-registry-for-my-docker-images)
      * [Using Persi NFS](#using-persi-nfs)
      * [How do I rotate the CCDB secrets?](#how-do-i-rotate-the-ccdb-secrets)

# Deploying SCF on Vagrant

## Requirements

1. We recommend running on a machine with more than 16G of ram _for now_.
1. You must install vagrant (1.9.5+): [https://www.vagrantup.com](https://www.vagrantup.com)
1. Install the following vagrant plugins

    * vagrant-libvirt (if using libvirt)
      ```bash
      vagrant plugin install vagrant-libvirt
      ```

## Deploying

Deploying on vagrant is highly scripted and so there should be very little to do to get
a working system.

1. Initial repo check out

    ```bash
    git clone --recurse-submodules https://github.com/SUSE/scf
    ```

2. Building the system

    ```bash
    # Bring the vagrant box up
    vagrant up --provider X # Where X is libvirt | virtualbox. See next section for additional options.

    # Once the vagrant box is up, ssh into it
    vagrant ssh

    # The scf directory you cloned has been mounted into the guest OS, cd into it
    cd scf

    # This runs a combination of bosh & fissile in order to create the docker
    # images and helm charts you'll need. Once this step is done you can see
    # images available via "docker images"
    make vagrant-prep
    # This is the final step, where it will install the uaa helm chart into the 'uaa' namespace
    # and the scf helm chart into the 'cf' namespace.
    make run

    # Watch the status of the pods, when everything is fully ready it should be usable.
    pod-status --watch

    # Currently the api role takes a very long time to do its migrations (~20 mins), to see if it's
    # doing migrations check the logs, if you see messages about migrations please be patient, otherwise
    # see the Troubleshooting guide.
    k logs -f cf:^api-[0-9]
    ```
3. Changing the default STEMCELL and STACK

   The default stemcell and stack are set to SUSE Linux Enterprise. The versions are defined
   in `bin/common/versions.sh`.

   The `FISSILE_DOCKER_REPOSITORY` environment variable will need to be set, and Docker
   configured to login to the repository.

   After changing the stemcell you have to remove the contents of
   `~vagrant/.fissile/compilation` and `~vagrant/scf/.fissile/compilation` inside
   the vagrant box. Afterwards recompile scf (for details see section "2. Building
   the system").

   **Example:**

   ```
   $ cd ~
   $ export FISSILE_DOCKER_REPOSITORY=registry.example.com
   $ docker login ${FISSILE_DOCKER_REPOSITORY} -u username -p password
   $ cd scf
   ```

3. Environment variables to configure `vagrant up` (optional)
    - `VAGRANT_VBOX_BRIDGE`: Set this to the name of an interface to enable bridged networking when
      using the Virtualbox provider. Turning on bridged networking will allow your vagrant box to receive
      an IP accessible anywhere on the network. While Virtualbox is able to bridge over an interface
      without any special networking configuration (and may even do this on OSX), bridged networking may
      not be supported when the provided interface is a wireless interface.See the [Virtualbox docs](
      https://www.virtualbox.org/manual/ch06.html#network_bridged) on bridged networking for more
      information.
    - `VAGRANT_KVM_BRIDGE`: Set this to the name of your host's linux bridge interface if you have one
      configured. If using Wicked as your network manager, you can configure one by setting the config
      files for your default interface and bridge interface as follows:
      ```
      #default interface:
      BOOTPROTO='none'
      STARTMODE='auto'
      DHCLIENT_SET_DEFAULT_ROUTE='yes'
      ```
      ```
      #bridged interface:
      DHCCLIENT_SET_DEFAULT_ROUTE='yes'
      STARTMODE='auto'
      BOOTPROTO='dhcp'
      BRIDGE='yes'
      BRIDGE_STP='off'
      BRIDGE_FORWARDDELAY='0'
      BRIDGE_PORTS='eth0'
      BRIDGE_PORTPRIORITIES='-'
      BRIDGE_PATHCOSTS='-'
      ```
      For example, if your default interface is named `eth0`', you would edit
      `/etc/sysconfig/network/ifcfg-eth0` and `/etc/sysconfig/network/ifcfg-br0`
      with the above settings. Then, after the desired configuration is in place, run
      `wicked ifreload all` and wait for wicked to apply the changes.
    - `VAGRANT_DHCP`: Set this to any value when using virtual networking (as opposed to bridged networking)
      in order to let your VM receive an IP via DHCP in the virtual network. If this environment variable is
      unset, the VM will instead obtain the IP cf-dev.io points to.


**Note:** If every role does not go green in `pod-status --watch` refer to [Troubleshooting](#troubleshooting)

3. Pulling updates

    When you want to pull the latest changes from the upstream you should:

    ```
    # Pull the changes (or checkout the commit you want):
    git pull

    # Update all submodules to match the checked out commit
    git submodule update --init --recursive
    ```

    Sometimes, when we bump the BOSH release submodules, they move to a different
    location and you need to run:

    ```
      git submodule sync --recursive
    ```

    You might have to run the `git submodule update --init --recursive` again after the
    last command.

    If there are untracked changes from submodule directories you can safely remove them.

    E.g. A command that will update all submodules and drop any changed or untracked files in them is:

    ```
      git submodule update --recursive --force && git submodule foreach --recursive 'git checkout . && git clean -fdx'
    ```

    **Make sure you understand what the [`git clean` flags mean](https://git-scm.com/docs/git-clean/) before you run this**

    Now you need to rebuild the images inside the vagrant box:

    ```
    make stop # And wait until all pods are stopped and removed
    make vagrant-prep kube run
    ```

## Usage

The vagrant box is set up with default certs, passwords, ips, etc. to make it easier
to run and develop on. So to access it and try it out all you should need is to get the
CF client and connect to it. Once you've connected with the CF cli you should be able to
do anything you can do with a vanilla Cloud Foundry.

You can get the the cf client here:
[github.com/cloudfoundry/cli](https://github.com/cloudfoundry/cli#downloads)

The way the vagrant box is created is by making a network with a static IP on the host.
This means that you cannot connect to it from some other box.

```bash
# Attach to the endpoint (self-signed certs in dev mode requires skipping validation).
# cf-dev.io resolves to the static IP that vagrant provisions.
# This DNS resolution may fail on certain DNS providers that block resolution to 192.168.0.0/16.
# Unless you changed the default credentials in the configuration, it is admin/changeme.
cf api --skip-ssl-validation https://api.cf-dev.io
cf login -u admin -p changeme
```

## Troubleshooting

Typically Vagrant box deployments encounter one of few problems:

* uaa does not come up correctly (constantly not ready in pod-status)

    In this case perform the following

    ```bash
    # Delete everything in the uaa namespace
    k delete namespace uaa

    # Delete the pv related to uaa/mysql-data-mysql-0
    k get pv # Find it
    k delete pv pvc-63aab845-4fe7-11e7-9c8d-525400652dd8

    make uaa-run
    ```

* api does not come up correctly and is not performing migrations (curl output in logs)

    uaa is not functioning, try steps above

* vagrant under VirtualBox freezing for no obvious reason: try enabling the "Use Host I/O Cache" option in `Settings->Storage->SATA Controller`.

* volumes don't get mounted when suspending/resuming the box

  For now only `vagrant stop` and then `vagrant up` fixes it.

* When restarting the box with either `vagrant reload` or `vagrant stop/up` some
  pods never come up automatically. You have to do a `make stop` and then
  `make run` to bring this up.

* Pulling images during any of `vagrant up` or `make vagrant-prep` or `make docker-deps`
  fails.

  In order to have access to the internet inside the vagrant box and inside the
  containers (withing the box) you need to enable ip forwarding for both the host
  and the vagrant box (which is the host for containers)

  To enable temporarily:

  ```echo "1" | sudo tee /proc/sys/net/ipv4/ip_forward```

  or to do this permanently:

  ```echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/50-docker-ipv4-ipforward.conf```

  and restart your docker service (or run `vagrant up` again if changed on the host)

# Deploying SCF on Kubernetes

SCF is deployed via [Helm](https://github.com/kubernetes/helm) on Kubernetes.
Please see the wiki page for [installation instructions](https://github.com/SUSE/scf/wiki/How-to-Install-SCF)
if you have a running Kubernetes already.

## Makefile targets

### Vagrant VM Targets

Name            | Effect |
--------------- | ---- |
`run`            | Set up SCF on the current node |
`stop`            | Stop SCF on the current node |
`vagrant-box`    | Build the Vagrant box image using `packer` |
`vagrant-prep`    | Shortcut for building everything needed for `make run` |

# Deployment Customizations

## Customize The Application Domain

In a standard installation, the domain used by applications pushed to
CF is the same as the domain configured for CF.

This document describes how to change this behaviour so that CF and
applications use separate domains.

:warning: The changes described below will work only for CAP 1.3.1,
and higher. They do not work for CAP 1.3, and will not work for the
CAP 2 series to be.

1. Follow the basic steps for deploying UAA and SCF.
1. When deploying SCF, add a section like

   ```
   bosh:
     instance_groups:
     - name: api-group
       jobs:
       - name: cloud_controller_ng
         properties:
           app_domains:
           - <APPDOMAIN>
   ```

   to the `scf-config-values.yaml` override file. The placeholder
   `<APPDOMAIN>` has to be replaced with whatever domain is desired to
   be used by the applications.

After deployment use

```
cf curl /v2/info | grep endpoint
```

to verify that the CF domain is __not__ `<APPDOMAIN>`.

Further, by pushing an application, verify that `<APPDOMAIN>` is
printed as the domain used by the application.

# Development FAQ

### Where do I find logs?

There are two places to see logs. Monit's logs, and the actual log files of each process in the
container.

1. Monit logs

    ```bash
    # Normal form using kubectl
    kubectl logs --namespace cf router-3450916350-xb3kf
    # Short form using k
    k logs cf:^router-[0-9]
    ```

1. Container process logs

    ```bash
    # Normal form
    kubectl exec -it --namespace cf nats-0 -- env LINES=$LINES COLS=$COLS TERM=$TERM bash
    # Short form
    k ssh :nats

    # After ssh'ing, the logs are all in this directory for each process:
    cd /var/vcap/sys/log
    ```

### How do I clear all data and begin anew without rebuilding everything?

On the Vagrant box, run the following commands:

```bash
make stop
make run
```

### How do I tear down a cluster on a cloud provider?

The [SCF secret generator](https://github.com/SUSE/scf-secret-generator)
creates secrets in the CF and UAA namespaces, and helm doesn't know about
these, which means they won't be deleted if the release is deleted.  The best
way to remove everything is to run the following commands:

```bash
helm delete --purge ${CF_RELEASE_NAME}
kubectl delete namespace ${CF_NAMESPACE}
helm delete --purge ${UAA_RELEASE_NAME}
kubectl delete namespace ${UAA_NAMESPACE}
```

However, busy systems may encounter timeouts when the release is deleted:

```bash
$ helm delete --purge scf
E0622 02:27:17.555417   14014 portforward.go:178] lost connection to pod
Error: transport is closing
```

In this case, deleting the StatefulSets before anything else will make the
operation more likely to succeed:

```bash
kubectl delete statefulsets --all --namespace ${CF_NAMESPACE}
helm delete --purge ${CF_RELEASE_NAME}
kubectl delete namespace ${CF_NAMESPACE}
kubectl delete statefulsets --all --namespace ${UAA_NAMESPACE}
helm delete --purge ${UAA_RELEASE_NAME}
kubectl delete namespace ${UAA_NAMESPACE}
```

Note that this needs kubectl v1.9.6 or newer for the `delete statefulsets` command to work.

### How do I run smoke and acceptance tests?

On the Vagrant box, when `pod-status` reports all roles are running, enable `diego_docker` support with

```bash
cf enable-feature-flag diego_docker
```

and execute the following commands:

```bash
make smoke
make brain
make scaler-smoke
make cats
```

#### How do I run a subset of SCF acceptance tests?

Deploy `acceptance-tests-brain` as above, but first modify the environment to include `INCLUDE=pattern` or
`EXCLUDE=pattern`.    For example to run just `005_sso_test.sh` and `014_sso_authenticated_passthrough_test.sh`, you
could add `INCLUDE` with a value of `sso`.

It is also possible to run custom tests by mounting them at the `/tests` mountpoint inside the container.    The
mounted tests will be combined with the bundled tests. However, to do so you will need to manually run it via docker.
To exclude the bundled tests match against names starting with 3 digits followed by an underscore (as in,
`EXCLUDE=\b\d{3}_`) or explicitly select only the mounted tests with `INCLUDE=^/tests/`.

#### How do I run a subset of Cloud Foundry acceptance tests?

Run `make/tests acceptance-tests env.CATS_SUITES="-suite,+suite" env.CATS_FOCUS="regular expression"`
directly.  Each suite is separated by a comma.  The modifiers apply until the next modifier is seen,
and have the following meanings:

Modifier | Meaning
--- | ---
`+` | Enable the following suites
`-` | Disable the following suites
`=` | Disable all suites, and enable the following suites

The `CATS_FOCUS` parameter is passed to [ginkgo] as a `-focus` parameter.

[ginkgo]: http://onsi.github.io/ginkgo/#the-ginkgo-cli

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

* Run the `vagrant reload` command.
* Run `vagrant halt && vagrant reload` command.
* Manually stop the virtual machine and then run the `vagrant reload` command.
* Run the `vagrant destroy -f && vagrant up` command and then run `make vagrant-prep run` on the Vagrant box.

### Can I target the cluster from the host using the `cf` CLI?

You can target the cluster on the hardcoded `cf-dev.io` address assigned to a host-only network adapter.
You can access any URL or endpoint that references this address from your host.

### How do I connect to the Cloud Foundry database?

1. Use the role manifest to expose the port for the mysql proxy role
2. The MySQL instance is exposed at `cf-dev.io:3306`.
3. The default username is: `root`.
4. You can find the password in the kubernetes secret.

### How do I add a new BOSH release to SCF?

1. Edit the `role-manifest.yml`:
    1. Add the BOSH release information to the `releases:` section
    1. Add new roles or change existing ones
    1. Add exposed environment variables (`yaml path: /variables`).
    1. Add configuration templates (`yaml path: /configuration/templates` and `yaml path: /roles/*/configuration/templates`).
1. Add development defaults for your configuration settings to `~/scf/bin/settings/settings.env`.
1. Add any opinions (static defaults) and dark opinions (configuration that must be set by user) to `./container-host-files/etc/scf/config/opinions.yml` and `./container-host-files/etc/scf/config/dark-opinions.yml`, respectively.
1. Test the changes.
    1. Run the `make compile images run` command.

### How do I expose new settings via environment variables?

1. Edit `./container-host-files/etc/scf/config/role-manifest.yml`:

    1. Add the new exposed environment variables (`yaml path: /variables`).
    1. Add or change configuration templates:

        1. `yaml path: /configuration/templates`
        1. `yaml path: /roles/*/configuration/templates`

1. Add development defaults for your new settings in `~/scf/bin/settings/settings.env`.
1. Rebuild the role images that need this new setting:

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

### How do I bump a BOSH release?

__Note:__ Because this process involves downloading and compiling release(s), it may take a long time.

1. In the manifest, update the version and SHA of the release(s)

1. Compare the BOSH releases


    ```bash
    make diff-releases
    ```

    This command will print all changes to releases, telling us what properties have changed (added,
   removed, changed descriptions and values, ...).

   > Note: don't commit the changes to the releases before you run the diff target.

1. Act on configuration changes:

    __Important:__ If you are not sure how to treat a configuration
    setting, discuss it with the SCF team.

    For any configuration changes discovered in step the previous
    step, you can do one of the following:

        * Keep the defaults in the new specification.
        * Add an opinion (static defaults) to `./container-host-files/etc/scf/config/opinions.yml`.
        * Add a template and an exposed environment variable to `./container-host-files/etc/scf/config/role-manifest.yml`.

    Define any secrets in the dark opinions file `./container-host-files/etc/scf/config/dark-opinions.yml` and expose them as environment variables.

1. Evaluate role changes:

    1. Consult the release notes of the new version of the release.
    1. If there are any role changes, discuss them with the SCF team, [follow steps 3 and 4 from this guide](#how-do-i-add-a-new-bosh-release-to-scf).

1. Test the release by running the `make compile images run` command.

1. Before committing the tested release update the line
   `export CF_VERSION=...` in `bin/common/version.sh` to the new CF version.

1. Cleanup the diff work dir (`/tmp/scf-releases-diff`)

### Can I suspend or resume my vagrant VM?

1. Run the `vagrant reload` command.
2. Run the `make run` command.

### How do I develop an upstream PR?

* If our submodules are close to the `HEAD` of upstream and no merge conflicts occur, follow [the steps described here](#if-im-working-on-component-x-how-does-my-dev-cycle-look-like).
* If merge conflicts occur, or if the component is referenced as a submodule, and it is not compatible with the parent release, work with the SCF team to resolve the issue on a case-by-case basis.

## How do I publish SCF and BOSH images?

1. Ensure that the Vagrant box is running.
1. `ssh` into the Vagrant box.
1. To tag the images into the selected registry and to push them, run the `make tag publish` command.
1. This target uses the `make` variables listed below to construct the image names and tags:

    | Variable       | Default          | Meaning |
    | -------------- | ---------------- | ------- |
    | IMAGE_REGISTRY | _empty_          | The name of the trusted registry to publish to |
    | IMAGE_PREFIX   | scf              | The prefix to use for image names (must not be empty) |
    | IMAGE_ORG      | splatform        | The organization in the image registry |
    | BRANCH         | _current branch_ | The tag to use for the images |

1. To publish to the standard trusted registry run the `make tag publish` command, for example:

    ```bash
    make tag publish IMAGE_REGISTRY=docker.example.com/
    ```

## How do I use an authenticated registry for my Docker images?

For testing purposes we can create an authenticated registry right inside
the Vagrant box.  But the instructions work just the same with a pre-existing
local registry.

The environment variables must be exported before changing into the `scf/`
directory. Otherwise `direnv` will remove the settings when switching to the
`src/uaa-fissile-release/` dir and back:

```
vagrant ssh
export FISSILE_DOCKER_REGISTRY=registry.cf-dev.io:5000
export FISSILE_DOCKER_USERNAME=admin
export FISSILE_DOCKER_PASSWORD=changeme
cd scf
time make vagrant-prep
```

`make secure-registries` will disallow access to insecure registries and register
the interal CA cert before restarting the docker daemon.

`make registry` will create a local docker registry re-using the router_ssl certs
and using basic auth. `make publish` will push all images to this registry:

```
make secure-registries
make registry
docker login -u $FISSILE_DOCKER_USERNAME -p $FISSILE_DOCKER_PASSWORD $FISSILE_DOCKER_REGISTRY
make publish
docker logout $FISSILE_DOCKER_REGISTRY
```

Log out to make sure that kube is using the registry credentials from the
helm chart and not the cached docker session.

Now delete all the local copies of the images. direnv allow is required to call
fissile from the UAA directory, and `FISSILE_REPOSITORY` needs to be overridden
from the `scf` setting that is inherited:

```
fissile show image | xargs docker rmi
cd src/uaa-fissile-release/
direnv allow
FISSILE_REPOSITORY=uaa fissile show image | xargs docker rmi
docker images
cd -
```

Now create an SCF and UAA instance via the helm chart and confirm that all
images are fetched correctly. Run smoke tests for final verification:

```
make run
pod-status --watch
docker images
make smoke
```

If the registry API needs to be accessed via curl, then it is easier to just use basic auth,
which can be requested by setting:

```
...
export FISSILE_DOCKER_AUTH=basic
make registry
curl -u ${FISSILE_DOCKER_USERNAME}:${FISSILE_DOCKER_PASSWORD} https://registry.cf-dev.io:5000/v2/
```

## Using Persi NFS


### Running a test NFS server

```bash
# Enable NFS modules
sudo modprobe nfs
sudo modprobe nfsd

docker run -d --name nfs \
    -v "[SOME_DIR_YOU_WANT_TO_SHARE_ON_YOUR_HOST]:/exports/foo" \
    -p 111:111/tcp \
    -p 111:111/udp \
    -p 662:662/udp \
    -p 662:662/tcp \
    -p 875:875/udp \
    -p 875:875/tcp \
    -p 2049:2049/udp \
    -p 2049:2049/tcp \
    -p 32769:32769/udp \
    -p 32803:32803/tcp \
    -p 892:892/udp \
    -p 892:892/tcp \
    --privileged \
    splatform/nfs-test-server /exports/foo
```

### Allow access to the NFS server

- Security group JSON file (nfs-sg.json). Replace `<destination_ip>` by the
  address returned from the command `getent hosts "cf-dev.io" | awk 'NR=1{print $1}'`:
```json
[
    {
        "destination": "<destination_ip>",
        "protocol": "tcp",
        "ports": "111,662,875,892,2049,32803"
    },
    {
        "destination": "<destination_ip>",
        "protocol": "udp",
        "ports": "111,662,875,892,2049,32769"
    }
]
```

```bash
# Create the security group - JSON above
cf create-security-group nfs-test nfs-sg.json
# Bind security groups for containers that run apps
cf bind-running-security-group nfs-test
# Bind security groups for containers that stage apps
cf bind-staging-security-group nfs-test
```

### Creating and testing a service

#### Get the pora app

```
git clone https://github.com/cloudfoundry/persi-acceptance-tests.git
cd persi-acceptance-tests/assets/pora
cf push pora --no-start
```

#### Test that writes work
```bash
# Enable the Persi NFS service
cf enable-service-access persi-nfs

# Create a service and bind it
EXTERNAL_IP=$(getent hosts "cf-dev.io" | awk 'NR=1{print $1}')
cf create-service persi-nfs Existing myVolume -c "{\"share\":\"${EXTERNAL_IP}/exports/foo\"}"
cf bind-service pora myVolume -c '{"uid":"1000","gid":"1000"}'

# Start the app
cf start pora
# Test the app is available
curl pora.cf-dev.io
# Test the app can write
curl pora.cf-dev.io/write
```

## How do I rotate the CCDB secrets?

The Cloud Controller Database encrypts sensitive information like passwords. By
default, the encryption key is [generated by SCF](https://github.com/SUSE/scf/blob/2d095a71008c33a23ca39d2ab9664e5602f8707e/container-host-files/etc/scf/config/role-manifest.yml#L1656-L1662).
If it's compromised and needs to be rotated, new keys can be added. Note that
existing encrypted information will **not** be updated. The encrypted information
must be set again to have them reencrypted with the new key. The old key cannot
be dropped until all references to it are removed from the database.

Updating these secrets is a manual process:

* Create a file `new-key-values.yaml` with content of the form:

```yaml
env:
  CC_DB_CURRENT_KEY_LABEL: new_key

secrets:
  CC_DB_ENCRYPTION_KEYS:
    new_key: "<new-key-value-goes-here>"
```

* Use
  `helm upgrade "${CF_NAMESPACE}" "${CF_CHART}" ... --values new-key-values.yaml`
  to import the above data into the cluster. This restarts relevant
  pods with the new information from step 1.

      - The variable `CF_NAMESPACE` contains the name of the namespace
        the SCF chart was deployed into.

      - The variable `CF_CHART` contains the name of the SCF chart.

      - The `...` placeholder stands for the standard set of options
        needed to properly upgrade an SCF deployment, as per the main
        documentation.

* Perform the actual rotation via

```shell
# Change the encryption key in the config file:
$ kubectl exec --namespace cf api-group-0 -- bash -c 'sed -i "/db_encryption_key:/c\\db_encryption_key: \"$(echo $CC_DB_ENCRYPTION_KEYS | jq -r .new_key)\"" /var/vcap/jobs/cloud_controller_ng/config/cloud_controller_ng.yml'

# Run the rotation for the encryption keys:
$ kubectl exec --namespace cf api-group-0 -- bash -c 'export PATH=/var/vcap/packages/ruby-2.4/bin:$PATH ; export CLOUD_CONTROLLER_NG_CONFIG=/var/vcap/jobs/cloud_controller_ng/config/cloud_controller_ng.yml ; cd /var/vcap/packages/cloud_controller_ng/cloud_controller_ng ; /var/vcap/packages/ruby-2.4/bin/bundle exec rake rotate_cc_database_key:perform'
```

When everything works correctly the first command will not generate
any output, while the second command will dump a series of
(json-formatted) log entries describing its progress in rotation the
keys for the various CC models.


Note that keys should be **appended** to the existing secret to be sure existing
environment variables can be decoded. Any operator can check which keys are in
use by accessing the `ccdb`. If the `encryption_key_label` is empty, the
default generated key is still being used.

```bash
$ kubectl -n cf exec mysql-0 -t -i -- /bin/bash -c 'mysql -p${MYSQL_ADMIN_PASSWORD}'
MariaDB [(none)]> select name, encrypted_environment_variables, encryption_key_label from ccdb.apps;
+--------+--------------------------------------------------------------------------------------------------------------+----------------------+
| name   | encrypted_environment_variables                                                                              | encryption_key_label |
+--------+--------------------------------------------------------------------------------------------------------------+----------------------+
| go-env | XF08q9HFfDkfxTvzgRoAGp+oci2l4xDeosSlfHJUkZzn5yvr0U/+s5LrbQ2qKtET0ssbMm3L3OuSkBnudZLlaCpFWtEe5MhUe2kUn3A6rUY= | key0                 |
+--------+--------------------------------------------------------------------------------------------------------------+----------------------+
1 row in set (0.00 sec)
```

For example, if keys were being rotated again, the secret would become:
```bash
SECRET_DATA=$(echo "{key0: abc-123, key1: def-456}" | base64)
```
and the `CC_DB_CURRENT_KEY_LABEL` would be updated to match the new key.

### Tables with Encrypted Information

The `ccdb` database contains several tables with encrypted information:

* apps: environment variables
* buildpack_lifecycle_buildpacks: buildpack URLs may contain passwords
* buildpack_lifecycle_data: buildpack URLs may contain passwords
* droplets: may contain docker registry passwords
* env_groups: environment variables
* packages: may contain docker registry passwords
* service_bindings: contains service credentials
* service_brokers: contains service credentials
* service_instances: contains service credentials
* service_keys: contains service credentials
* tasks: environment variables

To ensure the encryption key is updated, the command (or its `update-`
equivalent) can be run again with the same parameters. Some commands need to be deleted / recreated to update the label.

* apps: Run `cf set-env` again.
* buildpack_lifecycle_buildpacks, buildpack_lifecycle_data, droplets: `cf restage` the app
* packages: `cf delete`, then `cf push` the app (Docker apps with registry password)
* env_groups: Run `cf set-staging-environment-variable-group` or `cf set-running-environment-variable-group` again
* service_bindings: Run `cf unbind-service` and `cf bind-service` again
* service_brokers: Run `cf update-service-broker` with the appropriate credentials
* service_instances: Run `cf update-service` with the appropriate credentials
* service_keys: Run `cf delete-service-key` and `cf create-service-key` again.
* tasks: While tasks have an encryption key label, they are generally meant to be a
  one-off event, and left to run to completion. If there is a task still running, it
  could be stopped with `cf terminate-task`, then run again with `cf run-task`.
