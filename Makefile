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
	${GIT_ROOT}/make/bosh-release src/garden-linux-release

mysql-release:
	${GIT_ROOT}/make/bosh-release src/cf-mysql-release

cflinuxfs2-rootfs-release:
	${GIT_ROOT}/make/bosh-release src/cflinuxfs2-rootfs-release

hcf-deployment-hooks:
	${GIT_ROOT}/make/bosh-release src/hcf-deployment-hooks

hcf-sso-release:
	${GIT_ROOT}/make/bosh-release src/hcf-sso/hcf-sso-release

windows-runtime-release:
	${GIT_ROOT}/make/bosh-release src/windows-runtime-release windows-runtime-release

releases: cf-release usb-release diego-release etcd-release garden-release mysql-release cflinuxfs2-rootfs-release hcf-deployment-hooks windows-runtime-release hcf-sso-release

########## FISSILE BUILD TARGETS ##########

compile-base:
	${GIT_ROOT}/make/compile-base

# This is run from the Vagrantfile to copy in the existing compilation cache
copy-compile-cache:
	${GIT_ROOT}/make/compile restore

compile:
	${GIT_ROOT}/make/compile

images: bosh-images docker-images

image-base:
	${GIT_ROOT}/make/image-base

bosh-images:
	${GIT_ROOT}/make/bosh-images

docker-images:
	${GIT_ROOT}/make/images docker build

build: compile images

tag: bosh-tag docker-tag

bosh-tag:
	${GIT_ROOT}/make/images bosh tag

docker-tag:
	${GIT_ROOT}/make/images docker tag

publish: bosh-publish docker-publish

bosh-publish:
	${GIT_ROOT}/make/images bosh publish

docker-publish:
	${GIT_ROOT}/make/images docker publish

show-docker-setup:
	${GIT_ROOT}/make/show-docker-setup

show-versions:
	${GIT_ROOT}/make/show-versions

########## CONFIGURATION TARGETS ##########

generate: hcp mpc aws aws-spot aws-proxy aws-spot-proxy

hcp:
	${GIT_ROOT}/make/generate hcp

ucp-instance:
	${GIT_ROOT}/make/generate ucp-instance

ucp-instance-ha:
	${GIT_ROOT}/make/generate ucp-instance-ha

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

dist: mpc-dist aws-dist aws-spot-dist aws-proxy-dist aws-spot-proxy-dist

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
