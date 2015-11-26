#!/bin/bash

# __: was a '.' (2 underscores)
# ___: was a '-' (3 underscores)

export CONSUL=http://`/opt/hcf/bin/get_ip`:8501
var__uaa_clients_cc_routing_secret=cc_routing_secret
openstack_networking_floatingip_v2__hcf___core___host___fip__address=15.125.83.78
var__domain=xip.io
var__uaadb_username=uaaadmin
var__uaadb_password=uaaadmin_password
var__uaadb_tag=admin

/opt/hcf/bin/set-config $CONSUL hcf/user/etcd_metrics_server/machines '["nats.service.cf.internal"]'

# Used to just have this for hcf/user/etcd/machines
/opt/hcf/bin/set-config $CONSUL hcf/user/loggregator/etcd/machines '["etcd.service.cf.internal"]'

# If either of these is true configgin will want to resolve etcd.cluster
/opt/hcf/bin/set-config $CONSUL hcf/user/etcd/peer_require_ssl false
/opt/hcf/bin/set-config $CONSUL hcf/user/etcd/require_ssl false

/opt/hcf/bin/set-config $CONSUL hcf/user/uaa/clients/cc_routing/secret \"${var__uaa_clients_cc_routing_secret}\"

# And handle the route-registrar settings
/opt/hcf/bin/set-config $CONSUL hcf/role/uaa/route_registrar/routes "[{\"name\": \"uaa\", \"port\":\"8080\", \"tags\":{\"component\":\"uaa\"}, \"uris\":[\"uaa.${openstack_networking_floatingip_v2__hcf___core___host___fip__address}.${var__domain}\", \"*.uaa.${openstack_networking_floatingip_v2__hcf___core___host___fip__address}.${var__domain}\", \"login.${openstack_networking_floatingip_v2__hcf___core___host___fip__address}.${var__domain}\", \"*.login.${openstack_networking_floatingip_v2__hcf___core___host___fip__address}.${var__domain}\"]}]"

/opt/hcf/bin/set-config $CONSUL hcf/role/api/route_registrar/routes "[{\"name\":\"api\",\"port\":\"9022\",\"tags\":{\"component\":\"CloudController\"},\"uris\":[\"api.${openstack_networking_floatingip_v2__hcf___core___host___fip__address}.${var__domain}\"]}]"

/opt/hcf/bin/set-config $CONSUL hcf/role/hm9000/route_registrar/routes "[{\"name\":\"hm9000\",\"port\":\"5155\",\"tags\":{\"component\":\"HM9K\"},\"uris\":[\"hm9000.${openstack_networking_floatingip_v2__hcf___core___host___fip__address}.${var__domain}\"]}]"

/opt/hcf/bin/set-config $CONSUL hcf/role/loggregator_trafficcontroller/route_registrar/routes "[{\"name\":\"doppler\",\"port\":\"8081\",\"uris\":[\"doppler.${openstack_networking_floatingip_v2__hcf___core___host___fip__address}.${var__domain}\"]},{\"name\":\"loggregator_trafficcontroller\",\"port\":\"8080\",\"uris\":[\"loggregator.${openstack_networking_floatingip_v2__hcf___core___host___fip__address}.${var__domain}\"]}]"

/opt/hcf/bin/set-config $CONSUL hcf/role/doppler/route_registrar/routes "[{\"name\":\"doppler\",\"port\":\"8081\",\"uris\":[\"doppler.${openstack_networking_floatingip_v2__hcf___core___host___fip__address}.${var__domain}\"]},{\"name\":\"loggregator_trafficcontroller\",\"port\":\"8080\",\"uris\":[\"loggregator.${openstack_networking_floatingip_v2__hcf___core___host___fip__address}.${var__domain}\"]}]"

/opt/hcf/bin/set-config $CONSUL hcf/user/uaadb/roles "[{\"name\": \"${var__uaadb_username}\", \"password\": \"${var__uaadb_password}\", \"tag\": \"${var__uaadb_tag}\"}]"
