#!/bin/bash

## # # ## ### Tracing and common configuration ### ## # #

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)
SELFDIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd`
APP_NAME=php-mysql

export PATH="$PATH:${SELFDIR}/../test-resources/assets"

## # # ## ### Login & standard entity setup/cleanup ### ## # #

function login_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    # login to cf, during the test the previous login times out
    cf api --skip-ssl-validation api.${CF_DOMAIN}
    cf auth ${CF_USERNAME} ${CF_PASSWORD}

    cf target -o ${CF_ORG} -s ${CF_SPACE}

    cf delete -f ${APP_NAME}
    cf delete-space -f ${CF_SPACE}
    cf delete-org -f ${CF_ORG}

    set -o errexit
}
trap login_cleanup EXIT ERR

# login to HCP
hcp api https://${HCP_DOMAIN}:443 --skip-ssl-validation
hcp login -u $HCP_USERNAME -p $HCP_PASSWORD

# get HCP token
token=`cat $HOME/.hcp | jq -r .AccessToken`

# login to cf
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create organization
cf create-org ${CF_ORG}
cf target -o ${CF_ORG}

# create space
cf create-space ${CF_SPACE}
cf target -s ${CF_SPACE}

# push an app
cd ${SELFDIR}/../test-resources/${APP_NAME}
cf push ${APP_NAME}
cd -

API_COUNT=3
ROUTER_COUNT=3
API_WORKER_COUNT=3
LOGGREGATOR_COUNT=3
DOPPLER_COUNT=3
DIEGO_DATABASE_COUNT=3
DIEGO_CC_BRIDGE_COUNT=3
DIEGO_ROUTE_EMITTER_COUNT=3
NATS_COUNT=3
CONSUL_COUNT=3
ETCD_COUNT=3
MYSQL_COUNT=3
DIEGO_CELL_COUNT=1
ROUTING_HA_PROXY_COUNT=3
ROUTING_API_COUNT=3

# update IDL
curl -v -k \
-H "Content-Type: application/json" \
-H "Authorization: bearer ${token}" \
-X PATCH \
--data @<(cat <<EOF
{
    "instance_id": "$HCF_INSTANCE",
    "parameters": [
        {
            "name": "CONSUL_HCF_CLUSTER_CONFIG_REVISION",
            "value": "1"
        },
        {
            "name": "NATS_HCF_CLUSTER_CONFIG_REVISION",
            "value": "1"
        },
        {
            "name": "MYSQL_HCF_CLUSTER_CONFIG_REVISION",
            "value": "1"
        },
        {
            "name": "ETCD_HCF_CLUSTER_CONFIG_REVISION",
            "value": "1"
        }
    ],
    "scaling": [
      {
        "component": "api",
        "min_instances": $API_COUNT
      },
      {
        "component": "router",
        "min_instances": $ROUTER_COUNT
      },
      {
        "component": "api-worker",
        "min_instances": $API_WORKER_COUNT
      },
      {
        "component": "loggregator",
        "min_instances": $LOGGREGATOR_COUNT
      },
      {
        "component": "doppler",
        "min_instances": $DOPPLER_COUNT
      },
      {
        "component": "diego-database",
        "min_instances": $DIEGO_DATABASE_COUNT
      },
      {
        "component": "diego-cc-bridge",
        "min_instances": $DIEGO_CC_BRIDGE_COUNT
      },
      {
        "component": "diego-route-emitter",
        "min_instances": $DIEGO_ROUTE_EMITTER_COUNT
      },
      {
        "component": "nats",
        "min_instances": $NATS_COUNT
      },
      {
        "component": "consul",
        "min_instances": $CONSUL_COUNT
      },
      {
        "component": "etcd",
        "min_instances": $ETCD_COUNT
      },
      {
        "component": "mysql",
        "min_instances": $MYSQL_COUNT
      },
      {
        "component": "diego-cell",
        "min_instances": $DIEGO_CELL_COUNT
      },
      {
        "component": "routing-ha-proxy",
        "min_instances": $ROUTING_HA_PROXY_COUNT
      },
      {
        "component": "routing-api",
        "min_instances": $ROUTING_API_COUNT
      }
    ]
}
EOF
) \
https://${HCP_DOMAIN}:443/v1/instances/${HCF_INSTANCE}

# get instances
instances='instances.json'
n=0
until [ $n -gt 30 ]
do
    curl -k -H "Authorization: bearer ${token}" https://${HCP_DOMAIN}:443/v1/instances/${HCF_INSTANCE} > $instances

    apis=`cat $instances | jq '[.components[] | select (.name | match("\\\\Aapi-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    apiworkers=`cat $instances | jq '[.components[] | select (.name | match("\\\\Aapi-worker-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    routers=`cat $instances | jq '[.components[] | select (.name | match("\\\\Arouter-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    mysqls=`cat $instances | jq '[.components[] | select (.name | match("\\\\Amysql-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    loggregators=`cat $instances | jq '[.components[] | select (.name | match("\\\\Aloggregator-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    dopplers=`cat $instances | jq '[.components[] | select (.name | match("\\\\Adoppler-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    diegodatabases=`cat $instances | jq '[.components[] | select (.name | match("\\\\Adiego-database-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    diegoccbridges=`cat $instances | jq '[.components[] | select (.name | match("\\\\Adiego-cc-bridge-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    diegorouteemitters=`cat $instances | jq '[.components[] | select (.name | match("\\\\Adiego-route-emitter-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    consuls=`cat $instances | jq '[.components[] | select (.name | match("\\\\Aconsul-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    etcds=`cat $instances | jq '[.components[] | select (.name | match("\\\\Aetcd-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    diegocells=`cat $instances | jq '[.components[] | select (.name | match("\\\\Adiego-cell-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    nats=`cat $instances | jq '[.components[] | select (.name | match("\\\\Anats-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    routinghaproxy=`cat $instances | jq '[.components[] | select (.name | match("\\\\Arouting-ha-proxy-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`
    routingapi=`cat $instances | jq '[.components[] | select (.name | match("\\\\Arouting-api-\\\\d-\\\\d{8,10}-\\\\S{5}")) | select (.state.phase == "Running")] | length'`

    if [ $API_COUNT -eq $apis -a \
       $API_WORKER_COUNT -eq $apiworkers -a \
       $ROUTER_COUNT -eq $routers -a \
       $MYSQL_COUNT -eq $mysqls -a \
       $LOGGREGATOR_COUNT -eq $loggregators -a \
       $DOPPLER_COUNT -eq $dopplers -a \
       $DIEGO_DATABASE_COUNT -eq $diegodatabases -a \
       $DIEGO_ROUTE_EMITTER_COUNT -eq $diegorouteemitters -a \
       $DIEGO_CC_BRIDGE_COUNT -eq $diegoccbridges -a \
       $CONSUL_COUNT -eq $consuls -a \
       $ETCD_COUNT -eq $etcds -a \
       $DIEGO_CELL_COUNT -eq $diegocells -a \
       $ROUTING_HA_PROXY_COUNT -eq $routinghaproxy -a \
       $ROUTING_API_COUNT -eq $routingapi -a \
       $NATS_COUNT -eq $nats ] ; then
	# sleep for a while so that the app can be deleted
	    sleep 120
	    break
	else
	    if [ $n -eq 20 ] ; then
		    echo "Time out waiting for services to scale."
			exit 1
		fi

		echo "Running instances:"
		echo "api:                 $apis/$API_COUNT"
		echo "api-worker:          $apiworkers/$API_WORKER_COUNT"
		echo "router:              $routers/$ROUTER_COUNT"
		echo "mysql:               $mysqls/$MYSQL_COUNT"
		echo "loggregator:         $loggregators/$LOGGREGATOR_COUNT"
		echo "doppler:             $dopplers/$DOPPLER_COUNT"
		echo "diego-database:      $diegodatabases/$DIEGO_DATABASE_COUNT"
		echo "diego-route-emitter: $diegorouteemitters/$DIEGO_ROUTE_EMITTER_COUNT"
		echo "diego-cc-bridge:     $diegoccbridges/$DIEGO_CC_BRIDGE_COUNT"
		echo "consul:              $consuls/$CONSUL_COUNT"
		echo "etcd:                $etcds/$ETCD_COUNT"
		echo "diego-cell:          $diegocells/$DIEGO_CELL_COUNT"
		echo "nats:                $nats/$NATS_COUNT"
		echo "routing-ha-proxy:    $routinghaproxy/$ROUTING_HA_PROXY_COUNT"
		echo "routing-api:         $routingapi/$ROUTING_API_COUNT"
        n=$[$n+1]
	echo "Services did not scale yet. Sleeping..."
        sleep 30
	fi
done
