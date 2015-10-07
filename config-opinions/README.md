Each directory contains an `opinions.yml` and `dark-opinions.yml`.

The `opinions.yml` file contains a BOSH deployment manifest generated using [this script](https://github.com/cloudfoundry/cf-release/blob/master/scripts/generate_deployment_manifest) like it's specified [here](https://docs.cloudfoundry.org/deploying/openstack/install_cf_openstack.html)

The `cf-stub.yml` specified in the docs is the `dark-opinions.yml` opinions file.

The `dark-opinions.yml` file is also used by `fissile`, to determine which config values should not have defaults in the configuration base.

We can also use the `dark-opinions.yml` file to understand which values should be generated/configurable in the terraform scripts.
