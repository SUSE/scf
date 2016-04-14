# HCF High Availability Configuration

<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [HCF High Availability Configuration](#hcf-high-availability-configuration)
	- [Role manifest capabilities](#role-manifest-capabilities)
	- [Load balanced roles](#load-balanced-roles)
		- [By UCP](#by-ucp)
		- [Internally, by the gorouter and haproxy](#internally-by-the-gorouter-and-haproxy)
	- [Active/active & Active/passive roles](#activeactive-activepassive-roles)
	- [Self clustering roles](#self-clustering-roles)
	- [Non-HA](#non-ha)

<!-- /TOC -->

For upstream's recommendations see [this page](https://docs.cloudfoundry.org/concepts/high-availability.html#databases).

## Role manifest capabilities

1. Attributes describing scaling.

  - Example for `nats`:

    ```yaml
    - name: nats
      jobs: [...]
      processes: [...]
      run:
        scaling:
          - clone-index: 0
            min: 1
            max: 1
          - clone-index: 1
            min: 1
            max: 1
          - clone-index: 2
            min: 1
            max: 1
        ...
    ```

  - Example for `diego-cell`

    ```yaml
    - name: api
      jobs: [...]
      processes: [...]
      run:
        scaling:
          - clone-index: 0
            min: 1
            max: -1
        ...
    ```

2. The index configuration template in the role manifest.

  The template for `index` should be `((HCF_ROLE_INDEX))`.

  For roles that have more than one `clone-index` specified, the environment variable `((HCF_ROLE_INDEX))` should be automatically set to the correct value by our transformers.

  Once UCP gives us an environment variable for component instance index, we will need to update the `index` template to use it.
  This might only be possible after Kubernetes 1.3 is released.

## Load balanced roles

### By UCP

- ha-proxy/router
- diego-access
- mysql-proxy

Based on the upstream documentation, the HA Proxy role should not be required.
We should keep it for dev/test environments, but we should remove it from UCP.

To properly support HA for `diego-access` and `mysql-proxy`, we need to simulate what UCP does.
For testing, the solution is to use AWS [ELB](https://aws.amazon.com/elasticloadbalancing/).
Terraform has an [`ELB` resource](https://www.terraform.io/docs/providers/aws/r/elb.html).  
An HA configuration for these components in Vagrant/MPC is not be available.

The way to programmatically identify these components is by looking for roles that have public ports exposed.

These roles should have 1 `clone-index` definitions.

> Note: the [documentation](https://github.com/cloudfoundry/cf-mysql-release#create-load-balancer) for the MySQL proxy mentions that an active/passive balancing policy should be used, to decrease chances of deadlocking.
> It also mentions that health checking should be done on a specific port. Some of these requirements may not be supported by UCP.

### Internally, by the gorouter and haproxy

- router
- diego-cell
- uaa
- doppler
- loggregator
- blobstore
- cf-usb

These roles register with the gorouter (all except the gorouters themselves).

No specific transformer changes are required for these roles.

These roles should have 1 `clone-index` definitions.

- api

The API role is a special case, because it specifically needs only one instance to have an `index` of 0, so it can do database migrations.
The scaling definition for the API role should look like this:

```yaml
- name: api
  jobs: [...]
  processes: [...]
  run:
    scaling:
      - clone-index: 0
        min: 1
        max: 1
      - clone-index: 1
        min: 0
        max: -1
    ...
```

## Active/active & Active/passive roles

- api-worker
- clock-global
- diego-brain
- diego-cc-bridge
- diego-route-emitter

These roles can be horizontally scaled and they do not require to be load
balanced.

No specific transformer changes are required for these roles.

These roles should have 1 `clone-index` definitions.

## Self clustering roles

Each of the following components has a particular way for doing HA. These
components have to be scaled by using a "role duplication" artifice.

- nats
- consul
- mysql
- diego-database
- etcd

These roles should have 3 `clone-index` definitions.

> Note: For the mysql role we should use the `arbiter` role when available, to reduce footprint.

## Non-HA

- ha-proxy
  The HA Proxy role should only be used in development/test scenarios.
- windows-dns
  The Windows DNS role is only used to support development/test scenarios.
