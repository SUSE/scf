#!/bin/bash

set -e

IP=shift
if [ -z "$IP" ] ; then
  echo "Usage: $0 A.B.C.D where we're targeting node A.B.C.D"
  exit 1
fi

# init gato

ssh ubuntu@$IP gato api http://hcf-consul-server.hcf:8501

# Create some apps

bash -ex cf-run.bash $IP
#TODO: Make this configurable from the command-line
cd $HOME/lab/stackato/stackato-samples/sinatra-fibo
cf push fibo
cd ~/git/Stackato-Apps/go-env/
cf push goenv
cd ../node-env
cf push nodenv

# Manually fix consul:
scp /home/ericp/git/hpcloud/hcf-infrastructure/terraform-scripts/hcf/hcf-config-cf-v222.tar.gz ${IP}:/tmp/
ssh ubuntu@$IP bash -c 'bash /opt/hcf/bin/consullin.bash http://`/opt/hcf/bin/get_ip`:8501 /tmp/hcf-config-cf-v222.tar.gz'

# Update the consul kv store

scp upgrade-v222.bash ${IP}:
ssh ubuntu@$IP bash ./upgrade-v222.bash

# Get ready to upgrade

scp ../bootstrap-config/role-dependencies.json ${IP}:
scp upgrade-versions.rb ubuntu@${IP}:

ssh ubuntu@$IP sudo apt-get install -y ruby

# Add our registry

ssh ubuntu@$IP bash -c 'cp /etc/default/docker /tmp/default-docker.orig ; sed "s/--insecure-registry/--insecure-registry=15.125.71.0:5000 --insecure-registry/" /etc/default/docker > /tmp/docker.default && sudo cp /tmp/docker.default /etc/default/docker && sudo service docker restart'



ssh ubuntu@$IP bash -c 'echo "s/--insecure-registry/--insecure-registry=15.125.71.0:5000 --insecure-registry/p
w
q
" > ~/edscr ; sudo ed /etc/default/docker < ~/edscr'


echo 'On the server, run
ruby upgrade-versions.rb -t 222 -g latest-epdev -r 15.125.71.0:5000 -d ~/role-dependencies.yml 
'



