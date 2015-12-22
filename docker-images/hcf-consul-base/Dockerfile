FROM ubuntu:trusty
MAINTAINER hcf-dev@hpe.com
LABEL version="1.0"
RUN apt-get update && apt-get install -y curl wget unzip jq xmlstarlet && \
	wget -O /tmp/consul.zip https://dl.bintray.com/mitchellh/consul/0.5.2_linux_amd64.zip && \
	mkdir /opt/consul && unzip -d /opt/consul /tmp/consul.zip && rm /tmp/consul.zip
