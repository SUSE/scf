#!/usr/bin/env make

# Default target specification
run:

########## UTILITY TARGETS ##########

clean:
	make/clean

clean-harder: clean

all: images tag

print-version:
	@ make/print-version

########## TOOL DOWNLOAD TARGETS ##########

${FISSILE_BINARY}: bin/dev/install_tools.sh bin/common/versions.sh
	bin/dev/install_tools.sh

########## VAGRANT VM TARGETS ##########

certs: uaa-certs
	bin/generate-dev-certs.sh cf bin/settings/certs.env
	bin/settings/kube/ca.sh

uaa-certs:
	make/uaa-certs

uaa-releases:
	make/uaa-releases

uaa-kube-dist:
	make/uaa-kube-dist

run:
	make/uaa-run
	make/run

validate:
	make/validate

stop:
	make/stop
	make/uaa-stop

uaa-run:
	make/uaa-run

uaa-wait:
	make/uaa-wait

uaa-stop:
	make/uaa-stop

vagrant-box:
	make/vagrant-box

docker-deps:
	make/docker-deps

vagrant-prep: \
	docker-deps \
	releases \
	compile \
	images \
	${NULL}

registry:
	make/registry

smoke:
	make/tests smoke-tests

brain:
	make/tests acceptance-tests-brain

cats:
	make/tests acceptance-tests

########## BOSH RELEASE TARGETS ##########

diego-release:
	make/bosh-release src/diego-release

etcd-release:
	make/bosh-release src/etcd-release

garden-release:
	make/bosh-release src/garden-runc-release

mysql-release:
	RUBY_VERSION=2.3.1 make/bosh-release src/cf-mysql-release

usb-release:
	make/bosh-release src/cf-usb/cf-usb-release

cflinuxfs2-release:
	make/bosh-release src/cflinuxfs2-release

cf-opensuse42-release:
	make/bosh-release src/cf-opensuse42-release

cf-sle12-release:
	make/bosh-release src/cf-sle12-release

routing-release:
	make/bosh-release src/routing-release

hcf-release:
	make/bosh-release src/hcf-release

capi-release:
	make/bosh-release src/capi-release

grootfs-release:
	make/bosh-release src/grootfs-release

loggregator-release:
	make/bosh-release src/loggregator

nats-release:
	make/bosh-release src/nats-release

consul-release:
	make/bosh-release src/consul-release

binary-buildpack-release:
	make/bosh-release src/buildpacks/binary-buildpack-release

dotnet-core-buildpack-release:
	make/bosh-release src/buildpacks/dotnet-core-buildpack-release

go-buildpack-release:
	make/bosh-release src/buildpacks/go-buildpack-release

java-offline-buildpack-release:
	make/bosh-release src/buildpacks/java-offline-buildpack-release

nodejs-buildpack-release:
	make/bosh-release src/buildpacks/nodejs-buildpack-release

php-buildpack-release:
	make/bosh-release src/buildpacks/php-buildpack-release

python-buildpack-release:
	make/bosh-release src/buildpacks/python-buildpack-release

ruby-buildpack-release:
	make/bosh-release src/buildpacks/ruby-buildpack-release

staticfile-buildpack-release:
	make/bosh-release src/buildpacks/staticfile-buildpack-release

releases: \
	diego-release \
	etcd-release \
	garden-release \
	mysql-release \
	usb-release \
	cflinuxfs2-release \
	cf-opensuse42-release \
	cf-sle12-release \
	routing-release \
	hcf-release \
	capi-release \
	loggregator-release \
	nats-release \
	consul-release \
	binary-buildpack-release \
	dotnet-core-buildpack-release \
	go-buildpack-release \
	java-offline-buildpack-release \
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
	make/compile restore

clean-compile-cache:
	make/compile clean

compile: ${FISSILE_BINARY}
	make/compile

compile-clean: clean ${FISSILE_BINARY} vagrant-prep
	make/tar-sources

osc-commit-sources:
	make/osc-commit-sources

images: bosh-images uaa-images helm

bosh-images: validate ${FISSILE_BINARY}
	make/bosh-images

uaa-images: ${FISSILE_BINARY}
	make/compile restore
	make/uaa-images
	make/compile cache

build: compile images

publish: bosh-publish uaa-publish

bosh-publish: ${FISSILE_BINARY}
	make/bosh-publish

uaa-publish: ${FISSILE_BINARY}
	make/uaa-publish

show-docker-setup:
	make/show-docker-setup

show-versions:
	bin/common/versions.sh
	make/show-versions

########## KUBERNETES TARGETS ##########
kube kube/bosh-task/post-deployment-setup.yaml: uaa-kube
	bin/settings/kube/ca.sh
	bin/generate-dev-certs.sh cf bin/settings/certs.env
	make/kube
.PHONY: kube

helm helm/bosh-task/post-deployment-setup.yaml: uaa-helm
	bin/settings/kube/ca.sh
	bin/generate-dev-certs.sh cf bin/settings/certs.env
	make/kube helm
.PHONY: helm

uaa-kube: ${FISSILE_BINARY}
	make/uaa-kube
.PHONY: uaa-kube

uaa-helm: ${FISSILE_BINARY}
	make/uaa-kube helm
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
	make/kube-dist
	rm -rf kube

bundle-dist: kube-dist cert-generator 
	make/bundle-dist

########## SUPPORT  TARGETS ##########

cert-generator:
	make/cert-generator
