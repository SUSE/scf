# Minikube

For developing with Minikube, start a local cluster by running the `start` target:

```txt
bazel run //dev/minikube:start
```

## Managing system resources

The following environment variables are used by the `start` target to allocate the resources used by
Minikube:

  - VM_DRIVER - the driver to be used by Minikube for the virtualization. Available options:
      - virtualbox
      - kvm2
  - VM_CPUS - the number of CPUs Minikube will use.
  - VM_MEMORY - the amount of RAM Minikube will be allowed to use.
  - VM_DISK_SIZE - the disk size Minikube will be allowed to use.

E.g.:

```txt
VM_CPUS=6 VM_MEMORY=$((1024 * 24)) VM_DISK_SIZE=180g bazel run //dev/minikube:start
```

## Specifying a different Kubernetes version

Set the `K8S_VERSION` environment variable to override the default version.

## VM Drivers

At the moment, only the VirtualBox driver is working correctly; the kvm2 driver
is known to not work (no output, and the network does not come up).
