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

run:
	make/uaa-run
	make/uaa-wait
	make/run

upgrade:
	make/uaa-upgrade
	make/uaa-wait
	make/upgrade

wait:
	make/wait cf

validate:
	make/validate

stop:
	make/stop
	make/uaa-stop
	make/wait cf
	make/wait uaa

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

secure-registries:
	make/secure-registries

smoke:
	make/tests smoke-tests

brain:
	make/tests acceptance-tests-brain

cats:
	make/tests acceptance-tests

########## UAA LINK TARGETS ##########

uaa-releases:
	make/uaa-releases

uaa-kube-dist:
	make/uaa-kube-dist

uaa-run:
	make/uaa-run

uaa-wait:
	make/uaa-wait

uaa-stop:
	make/uaa-stop

uaa-upgrade:
	make/uaa-upgrade

uaa-compile: ${FISSILE_BINARY}
	make/compile restore
	make/uaa-compile
	make/compile cache

uaa-images: ${FISSILE_BINARY}
	make/uaa-images

uaa-publish: ${FISSILE_BINARY}
	make/uaa-publish

uaa-kube: ${FISSILE_BINARY}
	make/uaa-kube
.PHONY: uaa-kube

uaa-helm: ${FISSILE_BINARY}
	make/uaa-kube helm
.PHONY: uaa-helm

########## BOSH RELEASE TARGETS ##########

diego-release:
	make/bosh-release src/diego-release

garden-release:
	make/bosh-release src/garden-runc-release

mysql-release:
	RUBY_VERSION=2.3.1 make/bosh-release src/cf-mysql-release

networking-release:
	make/bosh-release src/cf-networking-release

smoke-tests-release:
	make/bosh-release src/cf-smoke-tests-release

usb-release:
	make/bosh-release src/cf-usb/cf-usb-release

nfs-volume-release:
	make/bosh-release src/nfs-volume-release

cflinuxfs2-release:
	make/bosh-release src/cflinuxfs2-release

cf-opensuse42-release:
	make/bosh-release src/cf-opensuse42-release

cf-sle12-release:
	make/bosh-release src/cf-sle12-release

cf-syslog-drain-release:
	make/bosh-release src/cf-syslog-drain-release

routing-release:
	make/bosh-release src/routing-release

scf-helper-release:
	make/bosh-release src/scf-helper-release

capi-release:
	make/bosh-release src/capi-release

loggregator-release:
	make/bosh-release src/loggregator-release

nats-release:
	make/bosh-release src/nats-release

statsd-injector-release:
	make/bosh-release src/statsd-injector-release

binary-buildpack-release:
	make/bosh-release src/buildpacks/binary-buildpack-release

dotnet-core-buildpack-release:
	make/bosh-release src/buildpacks/dotnet-core-buildpack-release

go-buildpack-release:
	make/bosh-release src/buildpacks/go-buildpack-release

java-buildpack-release:
	make/bosh-release src/buildpacks/java-buildpack-release

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
	garden-release \
	mysql-release \
	networking-release \
	smoke-tests-release \
	usb-release \
	nfs-volume-release \
	cflinuxfs2-release \
	cf-opensuse42-release \
	cf-sle12-release \
	cf-syslog-drain-release \
	routing-release \
	scf-helper-release \
	capi-release \
	loggregator-release \
	nats-release \
	statsd-injector-release \
	binary-buildpack-release \
	dotnet-core-buildpack-release \
	go-buildpack-release \
	java-buildpack-release \
	nodejs-buildpack-release \
	php-buildpack-release \
	python-buildpack-release \
	ruby-buildpack-release \
	staticfile-buildpack-release \
	uaa-releases \
	${NULL}

########## FISSILE BUILD TARGETS ##########

# This is run from the Vagrantfile to copy in the existing compilation cache
copy-compile-cache:
	make/compile restore

clean-compile-cache:
	make/compile clean

compile: ${FISSILE_BINARY}
	make/compile
	make/compile restore
	make/uaa-compile
	make/compile cache

compile-clean: clean ${FISSILE_BINARY} vagrant-prep
	make/tar-sources

osc-commit-sources:
	make/osc-commit-sources

images: bosh-images uaa-images helm kube

bosh-images: validate ${FISSILE_BINARY}
	make/bosh-images

build: compile images

publish: bosh-publish uaa-publish

bosh-publish: ${FISSILE_BINARY}
	make/bosh-publish

show-docker-setup:
	make/show-docker-setup

show-versions:
	bin/common/versions.sh
	make/show-versions

########## KUBERNETES TARGETS ##########

kube: uaa-kube
	make/kube
.PHONY: kube

helm: uaa-helm
	make/kube helm
.PHONY: helm

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

bundle-dist: kube-dist
	make/bundle-dist
