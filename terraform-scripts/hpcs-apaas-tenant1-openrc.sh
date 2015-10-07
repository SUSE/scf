#!/bin/bash

# To use an Openstack cloud you need to authenticate against keystone, which
# returns a **Token** and **Service Catalog**.  The catalog contains the
# endpoint for all services the user/tenant has access to - including nova,
# glance, keystone, swift.
#
# *NOTE*: Using the 2.0 *auth api* does not mean that compute api is 2.0.  We
# will use the 1.1 *compute api*
export OS_AUTH_URL=https://region-a.geo-1.identity.hpcloudsvc.com:35357/v2.0/

# With the addition of Keystone we have standardized on the term **tenant**
# as the entity that owns the resources.
export OS_TENANT_ID=54026737306152
export OS_TENANT_NAME="hpcs-apaas-tenant1"

# In addition to the owning entity (tenant), openstack stores the entity
# performing the action as the **user**.
export OS_USERNAME="hpcs-apaas.eric"

# With Keystone you pass the keystone password.
if [ -f password ] ; then
  export OS_PASSWORD=`cat password`
else
  echo "Please enter your OpenStack Password: "
  read -sr OS_PASSWORD_INPUT
  export OS_PASSWORD=$OS_PASSWORD_INPUT
fi

DEFAULT_USERNAME=ubuntu   #TODO: Make this hcf
echo -n "Name of the user to run [$DEFAULT_USERNAME]: "
read -sr x
case $x in
  "") export RUNTIME_USERNAME=$DEFAULT_USERNAME ;;
  *) export RUNTIME_USERNAME="$x" ;;
esac

# If your configuration has multiple regions, we set that information here.
# OS_REGION_NAME is optional and only valid in certain environments.
export OS_REGION_NAME="region-b.geo-1"
# Don't leave a blank variable, unset it if it was empty
if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi
