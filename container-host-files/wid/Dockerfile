############################################################
# Dockerfile to build SCF workspace
# Based on Ubuntu
############################################################

# Set the base image to Ubuntu
FROM ubuntu:14.04

# File Author / Maintainer
MAINTAINER SCF

# Show all verison
ENV JQ_VERSION="1.5" GOLANG_VERSION="1.8" KUBECTL_VERSION="v1.7.1" HELM_CERTGEN_VERSION="1.0.0" GOROOT="/goroot" GOPATH="/gopath"

# Turn on universe packages
RUN apt-get update -y

# Install basics dependency
RUN apt-get install -y nginx openssh-server git-core openssh-client curl nano build-essential openssl libreadline6 libreadline6-dev curl zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison subversion pkg-config ca-certificates mercurial bzr ruby ruby-dev libxslt1-dev libpq-dev libmysqlclient-dev apt-transport-https software-properties-common dnsutils

# Install BOSH Cli
RUN gem install bosh_cli --no-ri --no-rdoc

# Install Cloud Foundry command line
RUN curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx -C /usr/local/bin

# Install latest kubectl
RUN curl -L "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl && chmod a+x /usr/local/bin/kubectl

# Install jq
RUN curl -L "https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64" -o /usr/local/bin/jq && chmod a+x /usr/local/bin/jq

# Install golang
RUN mkdir /goroot && mkdir /gopath && curl https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-amd64.tar.gz | tar xvzf - -C /goroot --strip-components=1
ENV PATH $PATH:$GOROOT/bin:$GOPATH/bin

# Install certstrap
RUN git clone https://github.com/square/certstrap /opt/bcf/certstrap && cd /opt/bcf/certstrap && ./build && cp /opt/bcf/certstrap/bin/certstrap-*-linux-amd64 /usr/local/bin/certstrap

# Install helm
RUN mkdir /opt/bcf/helm && curl -L https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get -o /opt/bcf/helm/get_helm.sh && chmod +x /opt/bcf/helm/get_helm.sh && /opt/bcf/helm/get_helm.sh && helm init --client-only

# install helm-certgen
RUN mkdir /opt/bcf/helm/helm-certgen && curl -L "https://github.com/SUSE/helm-certgen/releases/download/${HELM_CERTGEN_VERSION}/certgen-linux-amd64-1-0-0-1501794790-f3b21c90.tgz" | tar -zx -C /opt/bcf/helm/helm-certgen && helm plugin install /opt/bcf/helm/helm-certgen

# Install fissile
RUN git clone https://github.com/SUSE/fissile $GOPATH/src/github.com/SUSE/fissile && cd $GOPATH/src/github.com/SUSE/fissile && make tools && make build && mv $GOPATH/src/github.com/SUSE/fissile/build/linux-amd64/fissile /usr/local/bin/fissile

# Install stampy
RUN go get -d github.com/SUSE/stampy && cd $GOPATH/src/github.com/SUSE/stampy && make tools && make all && mv $GOPATH/src/github.com/SUSE/stampy/build/linux-amd64/stampy /usr/local/bin/stampy

# Install kctl
RUN go get -d github.com/aarondl/kctl && cd $GOPATH/src/github.com/aarondl/kctl && go build && mv kctl /usr/local/bin/k

# Install docker
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - && apt-key fingerprint 0EBFCD88 && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && apt-get update && apt-get install -y docker-ce

# Install direnv
RUN git clone https://github.com/direnv/direnv $GOPATH/src/github.com/direnv/direnv && cd $GOPATH/src/github.com/direnv/direnv && make install && echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

WORKDIR /

# Start docker deamon
# Doesn't start it for CI
#ENTRYPOINT service docker start && /bin/bash