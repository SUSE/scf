#!/bin/bash

set -e

IP=$1 ; shift
if [ -z "$IP" ] ; then
  echo "Usage: $0 A.B.C.D where we're targeting node A.B.C.D"
  exit 1
fi

# init gato

gato=$(ssh ubuntu@$IP cat /opt/hcf/bin/gato)
if [[ $gato =~ "-i -t" ]] ; then
  echo "Remove the -t on /opt/hcf/bin/gato on $IP"
  exit 1
fi  

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
scp upgrade-versions.rb ubuntu@${IP}:

ssh ubuntu@$IP sudo apt-get install -y ruby

# Restarting docker kills the registry, so we're going to first
# stop all the docker nodes, then add the --insecure-registry setting
# to docker, restart it, and then bring in new versions of the
# stopped containers.  Yes, this means hcf gets shut down during an upgrade :(

if false ; then

# **** This is where consul fails
# Try adding this:
cid=$(docker ps | awk '/hcf-consul-server/ { print $1 }')
docker network disconnect hcf $cid
docker stop $cid
docker kill $cid
docker rm $cid
# Restart docker (see below)

#*#
ssh ubuntu@$IP bash -c 'cp /etc/default/docker /tmp/default-docker.orig ; sed "s/--insecure-registry/--insecure-registry=15.125.71.0:5000 --insecure-registry/" /etc/default/docker > /tmp/docker.default && sudo cp /tmp/docker.default /etc/default/docker && sudo service docker restart'

# Run a new hcf-consul-server
cid=$(docker run -d --net=bridge --privileged=true --restart=unless-stopped -p 8401:8401 -p 8501:8501 -p 8601:8601 -p 8310:8310 -p 8311:8311 -p 8312:8312 --name hcf-consul-server -v /opt/hcf/bin:/opt/hcf/bin -v /opt/hcf/etc:/opt/hcf/etc -v /data/hcf-consul:/opt/hcf/share/consul -t 15.126.242.125:5000/hcf/consul-server:latest -bootstrap -client=0.0.0.0 --config-file /opt/hcf/etc/consul.json | tee /tmp/hcf-consul-server-output)
docker network connect hcf $cid

fi


echo 'On the server, run
ruby upgrade-versions.rb -t 222 -g latest-epdev -r 15.125.71.0:5000 -d ~/role-dependencies.yml 

or


ruby -rdebug upgrade-versions.rb -t 222 -g latest-epdev -r 15.125.71.0:5000 -d ~/role-dependencies.yml 

'

echo 'Also possible:

for x in cf-api cf-api_worker cf-clock_global ; do
  echo $x
  docker exec -t $x apt-get install -y libyaml-0-2
done
'



