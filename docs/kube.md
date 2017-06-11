# Running directly on Kubernetes

> This is an experimental branch - you'll need to build the tools yourself.

## Status of the work

The code in this branch is meant to create a containerized Cloud Foundry
distribution that can be deployed directly on Kubernetes.
This currently works on a local hyperkube deployment setup in HCF's vagrant box.
It also deploys on Google's container engine, however apps can't be deployed due
to the hard requirement for cgroup memory and swap accounting.

A list of items to guide this effort:
- [x] UAA as a separate deployment (role manifest, etc)
- [ ] Spike on a better way to manage hostname configurations
- [ ] Improve certificate generation
- [x] Spike on removing the need for setcap
- [x] Merge the fissile work back to "upstream"
- [ ] Implement validation for RM/opinions/vars/etc. in fissile
- [ ] Makefile targets for publishing images and dist-ing the kube configs
- [ ] BUG: env vars are not detected properly for pods - it looks like the pods get more than they need
- [ ] Spike on a nicer way for the user to set values for env vars
- [ ] Spike on using parameter references in kube to reduce the number of exposed variables
- [ ] Spike on using grootfs and newer runc to eliminate hard requirements for the kernel (AUFS and cgroup memory and swap accounting)
- [ ] HA Configurations
- [ ] Fix persi

## Building

We build HCF as described in the README.
That will generate Docker images we'll want to deploy on Kube.

Build the [standalone UAA](https://github.com/hpcloud/uaa-fissile-release) (we need the certificates from there).

Pick up the UAA CA certificate following `bin/settings/kube/ca.sh` (it assumes checkouts parallel to HCF.git).

Run `bin/generate-dev-certs.sh <k8s namespace> bin/settings/certs.env` to ensure
your certificates match the environment.  For this guide we use `cf` as the
Kubernetes namespace.

Run `make kube` to generate kubernetes configuration files in the `kube`
directory.

## Running

### Running hyperkube in the Vagrant VM

The `kubectl` CLI is already pre-installed in the vagrant VM.  To run hyperkube,
run `make hyperkube` in the HCF source directory.  It creates a `host-path`
storage class by default in order to automatically provision volumes.

After starting hyperkube, deploy UAA following instructions in the
[uaa-fissile-release](https://github.com/hpcloud/uaa-fissile-release) repository.

Next, create a namespace for all the objects we're about to create:

```sh
# The namespace must match what you used to generate the dev certs with
kubectl create namespace cf
```

Finally, create everything:

```sh
# -n <namespace> should match the namespace above
kubectl create -n cf -f ./kube/bosh
kubectl create -n cf -f ./kube/bosh-task/post-deployment-setup.yml
kubectl create -n cf -f ./kube/bosh-task/autoscaler-create-service.yml
kubectl create -n cf -f ./kube/bosh-task/sso-create-service.yml
```

## Stopping

To delete a deployed instance, run `kubectl delete`:
```sh
# -n <namespace> should match the namespace above
kubectl delete -n cf -f ./kube/bosh
kubectl delete -n cf -f ./kube/bosh-task/post-deployment-setup.yml
kubectl delete -n cf -f ./kube/bosh-task/autoscaler-create-service.yml
kubectl delete -n cf -f ./kube/bosh-task/sso-create-service.yml
```
You must also delete the persistent volume claims manually:
```sh
kubectl delete -n cf pvc --all
```

## No-brainer to Build and Run SCF on Hyperkube

To build and Run SCF on Hyperkube inside scf vagrant box, run the following commands:

```sh
vagrant up
vagrant ssh
bash scf/bin/cf-hyperkube-install.sh
```
