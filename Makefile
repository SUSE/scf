#!/usr/bin/env make

GIT_ROOT:=$(shell git rev-parse --show-toplevel)

# Default target specification
run:

.PHONY: docker-images

########## UTILITY TARGETS ##########

clean:
	${GIT_ROOT}/make/clean

reap:
	${GIT_ROOT}/make/reap

clean-harder: clean reap

all: images tag

print-version:
	@ ${GIT_ROOT}/make/print-version

########## TOOL DOWNLOAD TARGETS ##########

${FISSILE_BINARY}: bin/dev/install_tools.sh
	bin/dev/install_tools.sh

########## VAGRANT VM TARGETS ##########

run:
	${GIT_ROOT}/make/run

validate:
	${GIT_ROOT}/make/validate

stop:
	${GIT_ROOT}/make/stop

vagrant-box:
	${GIT_ROOT}/make/vagrant-box

vagrant-prep: \
	compile-base \
	releases \
	compile \
	image-base \
	images \
	${NULL}

registry:
	${GIT_ROOT}/make/registry

########## BOSH RELEASE TARGETS ##########

uaa-release:
	${GIT_ROOT}/make/bosh-release src/uaa-release

diego-release:
	${GIT_ROOT}/make/bosh-release src/diego-release

etcd-release:
	${GIT_ROOT}/make/bosh-release src/etcd-release

garden-release:
	${GIT_ROOT}/make/bosh-release src/garden-runc-release

mysql-release:
	RUBY_VERSION=2.3.1 ${GIT_ROOT}/make/bosh-release src/cf-mysql-release

cflinuxfs2-rootfs-release:
	${GIT_ROOT}/make/bosh-release src/cflinuxfs2-rootfs-release

routing-release:
	${GIT_ROOT}/make/bosh-release src/routing-release

hcf-release:
	${GIT_ROOT}/make/bosh-release src/hcf-release

capi-release:
	${GIT_ROOT}/make/bosh-release src/capi-release

grootfs-release:
	${GIT_ROOT}/make/bosh-release src/grootfs-release

loggregator-release:
	${GIT_ROOT}/make/bosh-release src/loggregator

nats-release:
	${GIT_ROOT}/make/bosh-release src/nats-release

consul-release:
	${GIT_ROOT}/make/bosh-release src/consul-release

binary-buildpack-release:
	${GIT_ROOT}/make/bosh-release src/buildpacks/binary-buildpack-release

go-buildpack-release:
	${GIT_ROOT}/make/bosh-release src/buildpacks/go-buildpack-release

java-buildpack-release:
	${GIT_ROOT}/make/bosh-release src/buildpacks/java-buildpack-release

nodejs-buildpack-release:
	${GIT_ROOT}/make/bosh-release src/buildpacks/nodejs-buildpack-release

php-buildpack-release:
	${GIT_ROOT}/make/bosh-release src/buildpacks/php-buildpack-release

python-buildpack-release:
	${GIT_ROOT}/make/bosh-release src/buildpacks/python-buildpack-release

ruby-buildpack-release:
	${GIT_ROOT}/make/bosh-release src/buildpacks/ruby-buildpack-release

staticfile-buildpack-release:
	${GIT_ROOT}/make/bosh-release src/buildpacks/staticfile-buildpack-release

releases: \
	diego-release \
	etcd-release \
	garden-release \
	mysql-release \
	cflinuxfs2-rootfs-release \
	routing-release \
	hcf-release \
	capi-release \
	uaa-release \
	loggregator-release \
	nats-release \
	consul-release \
	binary-buildpack-release \
	go-buildpack-release \
	java-buildpack-release \
	nodejs-buildpack-release \
	php-buildpack-release \
	python-buildpack-release \
	ruby-buildpack-release \
	staticfile-buildpack-release \
	grootfs-release \
	${NULL}

########## FISSILE BUILD TARGETS ##########

compile-base: ${FISSILE_BINARY}
	${GIT_ROOT}/make/compile-base

# This is run from the Vagrantfile to copy in the existing compilation cache
copy-compile-cache:
	${GIT_ROOT}/make/compile restore

clean-compile-cache:
	${GIT_ROOT}/make/compile clean

compile: ${FISSILE_BINARY}
	${GIT_ROOT}/make/compile

images: bosh-images docker-images

image-base: ${FISSILE_BINARY}
	${GIT_ROOT}/make/image-base

bosh-images: validate ${FISSILE_BINARY}
	${GIT_ROOT}/make/bosh-images

docker-images: validate
	${GIT_ROOT}/make/images docker build

build: compile images

tag: bosh-tag docker-tag

# This rule iterates over all bosh images, and tags them via the wildcard rule
bosh-tag: ${FISSILE_BINARY}
	${MAKE} $(foreach role,$(shell ${GIT_ROOT}/make/images bosh print),bosh-tag-${role})

# This rule iterates over all docker images, and tags them via the wildcard rule
docker-tag:
	${MAKE} $(foreach role,$(shell ${GIT_ROOT}/make/images docker print),docker-tag-${role})

publish: bosh-publish docker-publish

# This rule iterates over all bosh images, and publishes them via the wildcard rule
bosh-publish: ${FISSILE_BINARY}
	${MAKE} $(foreach role,$(shell ${GIT_ROOT}/make/images bosh print),bosh-publish-${role})

# This rule iterates over all docker images, and publishes them via the wildcard rule
docker-publish:
	${MAKE} $(foreach role,$(shell ${GIT_ROOT}/make/images docker print),docker-publish-${role})

# This wildcard rule tags one single bosh image
bosh-tag-%:
	make/images bosh tag $(@:bosh-tag-%=%)

# This wildcard rule tags one single docker image
docker-tag-%:
	make/images docker tag $(@:docker-tag-%=%)

# This wildcard rule publishes one single bosh image
bosh-publish-%:
	make/images bosh publish $(@:bosh-publish-%=%)

# This wildcard rule publishes one single docker image
docker-publish-%:
	make/images docker publish $(@:docker-publish-%=%)

show-docker-setup:
	${GIT_ROOT}/make/show-docker-setup

show-versions:
	${GIT_ROOT}/make/show-versions

########## KUBERNETES TARGETS ##########
kube:
	${GIT_ROOT}/make/kube
.PHONY: kube

hyperkube:
	${GIT_ROOT}/make/hyperkube
.PHONY: hyperkube

########## CONFIGURATION TARGETS ##########

generate: \
	kube \
	${NULL}

########## DISTRIBUTION TARGETS ##########

dist: \
	kube-dist \
	${NULL}

kube-dist: kube
	${GIT_ROOT}/make/package-kube
	rm -rf kube

########## HCF-PIPELINE-RUBY-BOSH DOCKER IMAGE TARGETS ##########

hcf-pipeline-ruby-bosh:
	${GIT_ROOT}/make/pipeline-ruby-bosh build tag push --version 2.3.1

build-hcf-pipeline-ruby-bosh:
	${GIT_ROOT}/make/pipeline-ruby-bosh --build

tag-hcf-pipeline-ruby-bosh:
	${GIT_ROOT}/make/pipeline-ruby-bosh --tag --version 2.3.1

push-hcf-pipeline-ruby-bosh:
	${GIT_ROOT}/make/pipeline-ruby-bosh --push --version 2.3.1
