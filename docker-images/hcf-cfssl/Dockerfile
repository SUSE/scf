FROM ubuntu:trusty
MAINTAINER hcf-dev@hpe.com
LABEL version="1.0"
RUN apt-get update && apt-get install -y curl wget unzip build-essential libltdl-dev git && \
	curl -L https://storage.googleapis.com/golang/go1.4.3.linux-amd64.tar.gz -o /tmp/golang.tar.gz && \
	cd /usr/local && sudo tar zxvf /tmp/golang.tar.gz && \
	GOPATH=$HOME PATH=/usr/local/go/bin:$GOPATH/bin:$PATH go get -u github.com/cloudflare/cfssl/cmd/... && \
	GOPATH=$HOME PATH=/usr/local/go/bin:$GOPATH/bin:$PATH cfssl version
RUN echo gopath = $HOME
RUN ls -l $HOME/bin
