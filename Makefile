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

${FISSILE_BINARY}: bin/dev/install_tools.sh bin/common/versions.sh bin/fissile
	bin/dev/install_tools.sh

########## VAGRANT VM TARGETS ##########

run: ingress-run
	make/uaa/run
	make/wait uaa
	make/run

upgrade:
	make/uaa/upgrade
	make/wait uaa
	make/upgrade

wait:
	make/wait cf

validate:
	make/validate

stop: ingress-stop
	make/stop
	make/uaa/stop
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

scaler-smoke:
	make/tests autoscaler-smoke

stratos-run:
	make/stratos/run
	make/stratos/metrics/run

stratos-stop:
	make/stratos/stop
	make/stratos/metrics/stop

istio-run:
	make/istio/run

istio-stop:
	make/istio/stop

ingress-run:
	make/ingress/run

ingress-stop:
	make/ingress/stop

########## SIDECAR SERVICE TARGETS ##########

mysql:
	make/deploy-mysql

########## UAA LINK TARGETS ##########

uaa-releases:
	make/uaa/releases

uaa-kube-dist:
	make/uaa/kube-dist

uaa-run:
	make/uaa/run

uaa-wait:
	make/wait uaa

uaa-stop:
	make/uaa/stop

uaa-upgrade:
	make/uaa/upgrade

uaa-compile: ${FISSILE_BINARY}
	make/compile restore
	make/uaa/compile
	make/compile cache

uaa-images: ${FISSILE_BINARY}
	make/uaa/images

uaa-publish: ${FISSILE_BINARY}
	make/uaa/publish

uaa-kube: ${FISSILE_BINARY}
	make/uaa/kube
.PHONY: uaa-kube

uaa-helm: ${FISSILE_BINARY}
	make/uaa/kube helm
.PHONY: uaa-helm

########## BOSH RELEASE TARGETS ##########

scf-release:
	make/bosh-release src/scf-release

releases: \
	scf-release \
	uaa-releases \
	${NULL}

diff-releases:
	make/diff-releases

########## FISSILE BUILD TARGETS ##########

# This is run from the Vagrantfile to copy in the existing compilation cache
copy-compile-cache:
	make/compile restore

clean-compile-cache:
	make/compile clean

compile: ${FISSILE_BINARY}
	make/compile
	make/compile restore
	make/uaa/compile
	make/compile cache

compile-clean: clean ${FISSILE_BINARY} vagrant-prep
	${MAKE} tar-sources

tar-sources:
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
