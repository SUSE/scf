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
- [ ] Merge the fissile work back to "upstream"
- [ ] Implement validation for RM/opinions/vars/etc. in fissile
- [ ] Makefile targets for publishing images and dist-ing the kube configs
- [ ] BUG: env vars are not detected properly for pods - it looks like the pods get more than they need
- [ ] Spike on a nicer way for the user to set values for env vars
- [ ] Spike on using parameter references in kube to reduce the number of exposed variables
- [ ] Spike on using grootfs and newer runc to eliminate hard requirements for the kernel (AUFS and cgroup memory and swap accounting)
- [ ] HA Configurations

## Building

Build fissile using the `kube` branch: https://github.com/hpcloud/fissile/tree/kube.

We build HCF as described in the README.
That will generate Docker images we'll want to deploy on Kube.

Build the [standalone UAA](https://github.com/hpcloud/uaa-fissile-release) (we need the certificates from there).

Pick up the UAA CA certificate following `bin/settings/kube/ca.sh` (it assumes checkouts parallel to HCF.git).

Next, we'll use a new fissile command that generates kubernetes configuration
files:

```
fissile build kube \
  -k ./kube \
  -D $(echo bin/settings/{,kube/}*.env | tr ' ' ,) \
  --use-memory-limits=false
```

This will generate kubernetes configuration files in `./kube`.
The settings in those files will have defaults based on the `.env` files specified
in the command above.
We don't use memory limits because the plan is to run everything locally.

## Running

### Running hyperkube in the Vagrant VM

Install the kubectl cli by following [these steps](https://coreos.com/kubernetes/docs/latest/configure-kubectl.html#download-the-kubectl-executable).

Run hyperkube:

```
sudo mkdir -p /var/lib/kubelet
sudo mount --bind /var/lib/kubelet /var/lib/kubelet
sudo mount --make-shared /var/lib/kubelet

docker run -d \
    --volume=/sys:/sys:rw \
    --volume=/var/lib/docker/:/var/lib/docker:rw \
    --volume=/var/lib/kubelet/:/var/lib/kubelet:rw,shared \
    --volume=/var/run:/var/run:rw \
    --net=host \
    --pid=host \
    --privileged \
    --name=kubelet \
    viovanov/hyperkube:v1.5.2 \
    /hyperkube kubelet \
        --hostname-override=127.0.0.1 \
        --api-servers=http://localhost:8080 \
        --config=/etc/kubernetes/manifests \
        --cluster-dns=10.0.0.10 \
        --cluster-domain=cluster.local \
        --allow-privileged --v=2
```

Create a `host-path` storage class (will be used to automatically provision volumes).

- Write the following to a file `storage-class.yml`:
```
---
kind: StorageClass
apiVersion: storage.k8s.io/v1beta1
metadata:
  name: persistent
provisioner: kubernetes.io/host-path
parameters:
```

- Then run:
```
kubectl create -f storage-class.yml
```

Deploy UAA following instructions in the [uaa-fissile-release](https://github.com/hpcloud/uaa-fissile-release) repository.

Next, create a namespace for all the objects we're about to create:

```
kubectl create namespace cf
```

Finally, create everything:

```
kubectl create -f ./kube/bosh
```
