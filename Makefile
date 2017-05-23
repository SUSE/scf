#!/usr/bin/env make

GIT_ROOT:=$(shell git rev-parse --show-toplevel)

# Default target specification
run:

.PHONY: docker-images mpc mpc-dist aws aws-dist hcp

########## UTILITY TARGETS ##########

clean:
	${GIT_ROOT}/make/clean

reap:
	${GIT_ROOT}/make/reap

clean-harder: clean reap

all: images tag terraform

print-version:
	@ ${GIT_ROOT}/make/print-version

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

cf-release:
	${GIT_ROOT}/make/bosh-release src/cf-release

usb-release:
	${GIT_ROOT}/make/bosh-release src/cf-usb/cf-usb-release

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

hcf-sso-release:
	${GIT_ROOT}/make/bosh-release src/hcf-sso/hcf-sso-release

hcf-versions-release:
	${GIT_ROOT}/make/bosh-release src/hcf-versions/hcf-versions-release

windows-runtime-release:
	${GIT_ROOT}/make/bosh-release src/windows-runtime-release windows-runtime-release

open-autoscaler-release:
	${GIT_ROOT}/make/bosh-release src/open-Autoscaler/bosh-release cf-open-autoscaler

releases:
	${MAKE} \
		$(or ${MAKEFLAGS}, -j$(or ${J},1)) \
		cf-release \
		usb-release \
		diego-release \
		etcd-release \
		garden-release \
		mysql-release \
		cflinuxfs2-rootfs-release \
		routing-release \
		hcf-release \
		windows-runtime-release \
		hcf-sso-release \
		hcf-versions-release \
		open-autoscaler-release \
		${NULL}

########## FISSILE BUILD TARGETS ##########

compile-base:
	${GIT_ROOT}/make/compile-base

# This is run from the Vagrantfile to copy in the existing compilation cache
copy-compile-cache:
	${GIT_ROOT}/make/compile restore

clean-compile-cache:
	${GIT_ROOT}/make/compile clean

compile:
	${GIT_ROOT}/make/compile

images: bosh-images docker-images

image-base:
	${GIT_ROOT}/make/image-base

bosh-images: validate
	${GIT_ROOT}/make/bosh-images

docker-images: validate
	${GIT_ROOT}/make/images docker build

build: compile images

tag: bosh-tag docker-tag

# This rule iterates over all bosh images, and tags them via the wildcard rule
bosh-tag:
	${MAKE} $(foreach role,$(shell ${GIT_ROOT}/make/images bosh print),bosh-tag-${role})

# This rule iterates over all docker images, and tags them via the wildcard rule
docker-tag:
	${MAKE} $(foreach role,$(shell ${GIT_ROOT}/make/images docker print),docker-tag-${role})

publish: bosh-publish docker-publish

# This rule iterates over all bosh images, and publishes them via the wildcard rule
bosh-publish:
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

########## CONFIGURATION TARGETS ##########

generate: \
	hcp \
	hcp-instance-basic-dev \
	hcp-instance-ha-dev \
	mpc \
	aws \
	aws-spot \
	aws-proxy \
	aws-spot-proxy \
	${NULL}

hcp:
	${GIT_ROOT}/make/generate hcp

hcp-instance-basic-dev:
	${GIT_ROOT}/make/generate instance-basic-dev

hcp-instance-ha-dev:
	${GIT_ROOT}/make/generate instance-ha-dev

mpc:
	${GIT_ROOT}/make/generate mpc

aws:
	${GIT_ROOT}/make/generate aws

aws-proxy:
	${GIT_ROOT}/make/generate aws-proxy

aws-spot:
	${GIT_ROOT}/make/generate aws-spot

aws-spot-proxy:
	${GIT_ROOT}/make/generate aws-spot-proxy

########## DISTRIBUTION TARGETS ##########

dist: \
	hcp-dist \
	mpc-dist \
	aws-dist \
	aws-spot-dist \
	aws-proxy-dist \
	aws-spot-proxy-dist \
	${NULL}

hcp-dist: hcp hcp-instance-basic-dev hcp-instance-ha-dev
	${GIT_ROOT}/make/package-hcp

mpc-dist: mpc
	${GIT_ROOT}/make/package-terraform mpc
	rm *.tf *.tf.json

aws-dist: aws
	${GIT_ROOT}/make/package-terraform aws
	rm *.tf *.tf.json

aws-spot-dist: aws-spot
	${GIT_ROOT}/make/package-terraform aws-spot
	rm *.tf *.tf.json

aws-proxy-dist: aws-proxy
	${GIT_ROOT}/make/package-terraform aws-proxy
	rm *.tf *.tf.json

aws-spot-proxy-dist: aws-spot-proxy
	${GIT_ROOT}/make/package-terraform aws-spot-proxy
	rm *.tf *.tf.json

mpc-terraform-tests:
	${GIT_ROOT}/make/terraform-tests mpc ${OS_SSH_KEY_PATH}

aws-terraform-tests:
	${GIT_ROOT}/make/terraform-tests aws ${AWS_PUBLIC_KEY_PATH} ${AWS_PRIVATE_KEY_PATH}

########## HCF-PIPELINE-RUBY-BOSH DOCKER IMAGE TARGETS ##########

hcf-pipeline-ruby-bosh:
	${GIT_ROOT}/make/pipeline-ruby-bosh build tag push --version 2.3.1

build-hcf-pipeline-ruby-bosh:
	${GIT_ROOT}/make/pipeline-ruby-bosh --build

tag-hcf-pipeline-ruby-bosh:
	${GIT_ROOT}/make/pipeline-ruby-bosh --tag --version 2.3.1

push-hcf-pipeline-ruby-bosh:
	${GIT_ROOT}/make/pipeline-ruby-bosh --push --version 2.3.1
