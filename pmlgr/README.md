# Poor Man's Firehose

1. Turn off access-checking in the loggregator_trafficcontroller role:

1.1. `docker rm -f $(docker kill $(docker ps -a | awk '/trafficcontroller/ {print $1}'$)`

1.2. Start a new LGR_TC container in interactive mode:

```
docker run  --privileged --cgroup-parent=instance --dns=127.0.0.1 --dns=8.8.8.8 -p 2842:2842 --name cf-loggregator_trafficcontroller -t -v /var/vcap/sys/logs:/var/vcap/sys/logs -i  --entrypoint=/bin/bash helioncf/cf-loggregator_trafficcontroller:latest
```
```
# vi /var/vcap/jobs-src/loggregator_trafficcontroller/templates/loggregator_trafficcontroller_ctl.erb
# find --config
# on same line, add -disableAccessControl (single hyphen)
# cd /opt/hcf
# CONSUL_IP=`Run get_ip on a node`
# bash -ex run.sh http://$CONSUL_IP:8501 hcf 14
```

Now at your client, run the line:

$ `echo | cf nozzle` - verify you get tons of output

Now filter it:

$ `echo | cf nozzle | ruby ./flm.rb`
