FROM helioncf/hcf-consul-base
MAINTAINER hcf-dev@hpe.com
LABEL version="1.0"
EXPOSE 8300 8301 8302 8400 8500 8600
ADD consul.json /opt/hcf/etc/consul.json
ADD check_health.bash /opt/hcf/bin/check_health.bash
ENTRYPOINT ["/opt/consul/consul", "agent", "-server"]
