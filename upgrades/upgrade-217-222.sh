#!/bin/bash

set -e

IP=$1
if [ -z "$IP" ] ; then
  echo "Usage: $0 A.B.C.D where we're targeting node A.B.C.D"
  exit 1
fi

# init gato

ssh ubuntu@$IP /opt/hcf/bin/gato api http://hcf-consul-server.hcf:8501

# Create some apps

pushd .
bash -ex cf-run.bash $IP
#TODO: Make this configurable from the command-line
cd $HOME/lab/stackato/stackato-samples/sinatra-fibo
cf push fibo
cd ~/git/Stackato-Apps/go-env/
cf push goenv
cd ../node-env
cf push nodenv
popd

# Manually fix consul:
scp /home/ericp/git/hpcloud/hcf-infrastructure/terraform-scripts/hcf/hcf-config-cf-v222.tar.gz ${IP}:/tmp/
# Do the next two steps because ssh ... `...` doesn't work
REMOTEIP=`ssh ubuntu@$IP /opt/hcf/bin/get_ip`
ssh ubuntu@$IP /opt/hcf/bin/consullin.bash http://${REMOTEIP}:8501 /tmp/hcf-config-cf-v222.tar.gz

# Update the consul kv store

scp upgrade-v222.bash ${IP}:
ssh ubuntu@$IP bash ./upgrade-v222.bash $IP

# Get ready to upgrade

scp ../bootstrap-config/role-dependencies.yml ${IP}:
# scp upgrade-versions.rb ubuntu@${IP}:
scp $HOME/lab/gostuff/src/hcfupgrade/hcfupgrade ubuntu@${IP}:

# Restarting docker kills the registry, so we're going to first
# stop all the docker nodes, then add the --insecure-registry setting
# to docker, restart it, and then bring in new versions of the
# stopped containers.  Yes, this means hcf gets shut down during an upgrade :(

echo 'On the server, run

./hcfupgrade -role-dependencies=$HOME/role-dependencies.yml -target-repository=15.125.71.0:5000 -target-tag="latest" -target-version=222
'

echo 'Also possible:

for x in cf-api cf-api_worker cf-clock_global ; do
  echo $x
  docker exec -t $x apt-get install -y libyaml-0-2
done
'



