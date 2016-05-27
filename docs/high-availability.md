# HCF High Availability Configuration

<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [HCF High Availability Configuration](#hcf-high-availability-configuration)
	- [Definitions](#definitions)
	- [Role manifest capabilities](#role-manifest-capabilities)
	- [Load balanced roles](#load-balanced-roles)
		- [By HCP](#by-hcp)
		- [Internally, by the gorouter and haproxy](#internally-by-the-gorouter-and-haproxy)
	- [Active/active & Active/passive roles](#activeactive-activepassive-roles)
	- [Self clustering roles](#self-clustering-roles)
	- [Non-HA](#non-ha)

<!-- /TOC -->

For upstream's recommendations see [this page](https://docs.cloudfoundry.org/concepts/high-availability.html#databases).

## Definitions

- **min:** minimum number of instances for a role
- **max:** maximum number of instances of a role
- **indexed:** the number of cloned components for a role

  [![HA scaling definitions](high-availability-scaling-definitions.png)](high-availability-scaling-definitions.md)

## Role manifest capabilities

1. Attributes describing scaling

  > Note: the scaling attribute and its child keys are mandatory.

  - Example for `nats`:

    ```yaml
    - name: nats
      jobs: [...]
      processes: [...]
      run:
        scaling:
          min: 3
          max: 3
          indexed: 3
        ...
    ```

    For the HCP, this will yield a configuration similar to (details cut for brevity):

    ```json
    "components": [
      {
        "name": "nats-0",
        "min_instances": 1,
        "max_instances": 1,
        "entrypoint": ["/usr/bin/env", "HCF_ROLE_INDEX=0", "/opt/hcf/run.sh"]
      },
      {
        "name": "nats-1",
        "min_instances": 1,
        "max_instances": 1,
        "entrypoint": ["/usr/bin/env", "HCF_ROLE_INDEX=1", "/opt/hcf/run.sh"]
      },
      {
        "name": "nats-2",
        "min_instances": 1,
        "max_instances": 1,
        "entrypoint": ["/usr/bin/env", "HCF_ROLE_INDEX=2", "/opt/hcf/run.sh"]
      }
    ]
    ```

  - Example for `diego-cell`

    ```yaml
    - name: diego-cell
      jobs: [...]
      processes: [...]
      run:
        scaling:
          min: 1
          max: 65535
          indexed: 1
        ...
    ```
    For the HCP, this will yield a configuration similar to (details cut for brevity):

    ```json
    "components": [
      {
        "name": "diego-cell",
        "min_instances": 1,
        "max_instances": 65535,
        "entrypoint": ["/usr/bin/env", "HCF_ROLE_INDEX=0", "/opt/hcf/run.sh"]
      }
    ]
    ```    

2. The index configuration template in the role manifest.

  The template for `index` should be `((HCF_ROLE_INDEX))`.

  For roles that have `scaling/indexed > 1`, the environment variable `((HCF_ROLE_INDEX))` should be automatically set to the correct value by our transformers. In HCP, this variable can only be set by modifying the entrypoint of the component, as shown in the examples at point #1. 

## Load balanced roles

### By HCP

- ha-proxy/router
- diego-access
- mysql-proxy

Based on the upstream documentation, the HA Proxy role should not be required.
We should keep it for dev/test environments, but we should remove it from HCP.

To properly support HA for `diego-access` and `mysql-proxy`, we need to simulate what HCP does.
For testing, the solution is to use AWS [ELB](https://aws.amazon.com/elasticloadbalancing/).
Terraform has an [`ELB` resource](https://www.terraform.io/docs/providers/aws/r/elb.html).  
An HA configuration for these components in Vagrant/MPC is not be available.

The way to programmatically identify these components is by looking for roles that have public ports exposed.

These roles should have `scaling/indexed == 1`.

> Note: the [documentation](https://github.com/cloudfoundry/cf-mysql-release#create-load-balancer) for the MySQL proxy mentions that an active/passive balancing policy should be used, to decrease chances of deadlocking.
> It also mentions that health checking should be done on a specific port. Some of these requirements may not be supported by HCP.

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

These roles should have `scaling/indexed == 1`.

- api

The API role is a special case, because it specifically needs only one instance to have an `index` of 0, so it can do database migrations.
The scaling definition for the API role should look like this:

```yaml
- name: api
  jobs: [...]
  processes: [...]
  run:
    scaling:
      min: 1
      max: 65535
      indexed: 2
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

These roles should have `scaling/indexed == 1`.

## Self clustering roles

Each of the following components has a particular way for doing HA. These
components have to be scaled by using a "role duplication" artifice.

- nats
- consul
- mysql
- diego-database
- etcd

These roles should have `scaling/indexed >= 2`, depending on documented recommendations.

> Note: For the mysql role we should use the `arbiter` role when available, to reduce footprint.

## Non-HA

- ha-proxy
  The HA Proxy role should only be used in development/test scenarios.
- windows-dns
  The Windows DNS role is only used to support development/test scenarios.
