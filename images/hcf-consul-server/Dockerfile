FROM 15.126.242.125:5000/hcf/consul-base
MAINTAINER hcf-dev@hpe.com
LABEL version="1.0"
ENV DATA_DIR="/tmp/consul"
EXPOSE 8300 8301 8302 8400 8500 8600 
ENTRYPOINT ["/opt/consul/consul", "agent", "-server", "-data-dir=\"${DATA_DIR}\""]
