#!/usr/bin/env make

GIT_ROOT:=$(shell git rev-parse --show-toplevel)

# Default target specification
run:

########## UTILITY TARGETS ##########

clean:
	${GIT_ROOT}/make/clean

clean-harder: clean

all: images tag

print-version:
	@ ${GIT_ROOT}/make/print-version

########## TOOL DOWNLOAD TARGETS ##########

${FISSILE_BINARY}: bin/dev/install_tools.sh
	bin/dev/install_tools.sh

########## VAGRANT VM TARGETS ##########

certs: uaa-certs
	${GIT_ROOT}/bin/generate-dev-certs.sh cf bin/settings/certs.env
	${GIT_ROOT}/bin/settings/kube/ca.sh

uaa-certs:
	${GIT_ROOT}/make/uaa-certs

uaa-releases:
	${GIT_ROOT}/make/uaa-releases

uaa-kube-dist:
	${GIT_ROOT}/make/uaa-kube-dist

run:
	${GIT_ROOT}/make/uaa-run
	${GIT_ROOT}/make/run

validate:
	${GIT_ROOT}/make/validate

stop:
	${GIT_ROOT}/make/stop
	${GIT_ROOT}/make/uaa-stop

uaa-run:
	${GIT_ROOT}/make/uaa-run

uaa-stop:
	${GIT_ROOT}/make/uaa-stop

vagrant-box:
	${GIT_ROOT}/make/vagrant-box

docker-deps:
	${GIT_ROOT}/make/docker-deps

vagrant-prep: \
	docker-deps \
	releases \
	compile \
	images \
	${NULL}

registry:
	${GIT_ROOT}/make/registry

smoke:
	${GIT_ROOT}/make/smoke

brain:
	${GIT_ROOT}/make/brain

cats:
	${GIT_ROOT}/make/cats

########## BOSH RELEASE TARGETS ##########

diego-release:
	${GIT_ROOT}/make/bosh-release src/diego-release

etcd-release:
	${GIT_ROOT}/make/bosh-release src/etcd-release

garden-release:
	${GIT_ROOT}/make/bosh-release src/garden-runc-release

mysql-release:
	RUBY_VERSION=2.3.1 ${GIT_ROOT}/make/bosh-release src/cf-mysql-release

cflinuxfs2-release:
	${GIT_ROOT}/make/bosh-release src/cflinuxfs2-release

cf-opensuse42-release:
	${GIT_ROOT}/make/bosh-release src/cf-opensuse42-release

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
	cflinuxfs2-release \
	cf-opensuse42-release \
	routing-release \
	hcf-release \
	capi-release \
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

# This is run from the Vagrantfile to copy in the existing compilation cache
copy-compile-cache:
	${GIT_ROOT}/make/compile restore

clean-compile-cache:
	${GIT_ROOT}/make/compile clean

compile: ${FISSILE_BINARY}
	${GIT_ROOT}/make/compile

images: bosh-images uaa-images helm

bosh-images: validate ${FISSILE_BINARY}
	${GIT_ROOT}/make/bosh-images

uaa-images: ${FISSILE_BINARY}
	${GIT_ROOT}/make/uaa-images

build: compile images

publish: bosh-publish uaa-publish

bosh-publish: ${FISSILE_BINARY}
	make/bosh-publish

uaa-publish: ${FISSILE_BINARY}
	make/uaa-publish

show-docker-setup:
	${GIT_ROOT}/make/show-docker-setup

show-versions:
	${GIT_ROOT}/bin/dev/versions.sh
	${GIT_ROOT}/make/show-versions

########## KUBERNETES TARGETS ##########
kube kube/bosh-task/post-deployment-setup.yml: uaa-kube
	${GIT_ROOT}/bin/settings/kube/ca.sh
	${GIT_ROOT}/make/kube
.PHONY: kube

helm helm/bosh-task/post-deployment-setup.yml: uaa-helm
	${GIT_ROOT}/bin/settings/kube/ca.sh
	${GIT_ROOT}/make/kube helm
.PHONY: helm

uaa-kube: ${FISSILE_BINARY}
	${GIT_ROOT}/make/uaa-kube
.PHONY: uaa-kube

uaa-helm: ${FISSILE_BINARY}
	${GIT_ROOT}/make/uaa-kube helm
.PHONY: uaa-helm

########## CONFIGURATION TARGETS ##########

generate: \
	kube \
	${NULL}

########## DISTRIBUTION TARGETS ##########

dist: \
	kube-dist \
	${NULL}

kube-dist: kube uaa-kube-dist
	${GIT_ROOT}/make/kube-dist
	rm -rf kube

########## SUPPORT  TARGETS ##########

cert-generator:
	${GIT_ROOT}/make/cert-generator


