#!/usr/bin/env make

GIT_ROOT:=$(shell git rev-parse --show-toplevel)

# Default target specification
run:

.PHONY: docker-images mpc mpc-dist aws aws-dist

UBUNTU_IMAGE ?= ubuntu:14.04

VERSION := $(shell cat VERSION)
VERSION_OFFSET := $(shell git describe --tags --long | sed -r 's/[0-9.]+-([0-9]+)-(g[a-f0-9]+)/\1.\2/')
BRANCH := $(shell (git describe --all --exact-match HEAD 2>/dev/null || echo HEAD) | sed 's@.*/@@')
APP_VERSION := ${VERSION}+${VERSION_OFFSET}.${BRANCH}
APP_VERSION_TAG := $(subst +,_,${APP_VERSION})

# CI configuration. Empty strings not allowed, except for the registry.
IMAGE_PREFIX   := hcf
IMAGE_ORG      := helioncf
IMAGE_REGISTRY := docker.helion.lol

# Where to find the secrets. By default (empty string) no secrets.
ENV_DIR        :=

# Note: When used the registry must not have a trailing "/". That is
# added automatically, see IMAGE_REGISTRY_MAKE for the make variable.
# Examples:
# - localhost:5000
# - docker.helion.lol

# NOTE 2: When ENV_DIR is used we automatically add the --env
# option. See ENV_DIR_MAKE below.

# Redefine the CI configuration variables, validation
IMAGE_ORG           := $(if ${IMAGE_ORG},${IMAGE_ORG},$(error Need a non-empty IMAGE_ORG))
IMAGE_PREFIX        := $(if ${IMAGE_PREFIX},${IMAGE_PREFIX},$(error Need a non-empty IMAGE_PREFIX))
IMAGE_REGISTRY_MAKE := $(if ${IMAGE_REGISTRY},"${IMAGE_REGISTRY}/",${IMAGE_REGISTRY})
ENV_DIR_MAKE        := $(if ${ENV_DIR},--env "${ENV_DIR}",)

# The variables are defaults; see bin/.fissilerc for defaults for the vagrant box
export FISSILE_RELEASE ?= ${CURDIR}/src/cf-release,${CURDIR}/src/cf-usb/cf-usb-release,${CURDIR}/src/diego-release,${CURDIR}/src/etcd-release,${CURDIR}/src/garden-linux-release,${CURDIR}/src/cf-mysql-release,${CURDIR}/src/hcf-deployment-hooks,${CURDIR}/src/windows-runtime-release
export FISSILE_ROLES_MANIFEST ?= ${CURDIR}/container-host-files/etc/hcf/config/role-manifest.yml
export FISSILE_LIGHT_OPINIONS ?= ${CURDIR}/container-host-files/etc/hcf/config/opinions.yml
export FISSILE_DARK_OPINIONS ?= ${CURDIR}/container-host-files/etc/hcf/config/dark-opinions.yml
export FISSILE_DEV_CACHE_DIR ?= ${HOME}/.bosh/cache
export FISSILE_WORK_DIR ?= ${CURDIR}/_work

########## UTILITY TARGETS ##########

print_status = @printf "\033[32;01m==> ${1}\033[0m\n"

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
	${GIT_ROOT}/make/bosh-release src/cf-usb-release

diego-release:
	${GIT_ROOT}/make/bosh-release src/diego-release

etcd-release:
	${GIT_ROOT}/make/bosh-release src/etcd-release

garden-release:
	${GIT_ROOT}/make/bosh-release src/garden-linux-release

mysql-release:
	${GIT_ROOT}/make/bosh-release src/cf-mysql-release

hcf-deployment-hooks:
	${GIT_ROOT}/make/bosh-release src/hcf-deployment-hooks

windows-runtime-release:
	${GIT_ROOT}/make/bosh-release src/windows-runtime-release

releases: cf-release usb-release diego-release etcd-release garden-release mysql-release hcf-deployment-hooks windows-runtime-release

########## FISSILE BUILD TARGETS ##########

compile-base:
	${GIT_ROOT}/make/compile-base

# This is run from the Vagrantfile to copy in the existing compilation cache
copy-compile-cache:
	$(call print_status, Copying compilation cache)
	mkdir -p "${FISSILE_WORK_DIR}/compilation/"
ifneq (,${HCF_PACKAGE_COMPILATION_CACHE})
	mkdir -p "${HCF_PACKAGE_COMPILATION_CACHE}"
	# rsync takes the first match; need to explicitly include parent directories in order to include the children.
	rsync -rl --include="/*/" --include="/*/*/" --include="/*/*/compiled.tar" --exclude="*" --info=progress2 "${HCF_PACKAGE_COMPILATION_CACHE}/" "${FISSILE_WORK_DIR}/compilation/"
	for i in ${FISSILE_WORK_DIR}/compilation/*/*/compiled.tar ; do \
		[ -e $${i} ] || continue ; \
		i=$$(dirname $${i}) ; \
		echo unpack $${i} ; \
		rm -rf $${i}/compiled ; \
		tar xf $${i}/compiled.tar -C "$${i}" ; \
	done ; true
endif

compile:
	$(call print_status, Compiling BOSH release packages)
	@echo Please allow a long time for mariadb to compile
	fissile dev compile
ifneq (,${HCF_PACKAGE_COMPILATION_CACHE})
	# rsync takes the first match; need to explicitly include parent directories in order to include the children.
	{ \
		set -e ; \
		for i in ${FISSILE_WORK_DIR}/compilation/*/*/compiled ; do \
			i=$$(dirname $${i}) ; \
			echo pack $${i} ; \
			tar cf $${i}/compiled.tar -C "$${i}" compiled ; \
		done ; \
		rsync -rl --include="/*/" --include="/*/*/" --include="/*/*/compiled.tar" --exclude="*" --info=progress2 --ignore-existing "${FISSILE_WORK_DIR}/compilation/" "${HCF_PACKAGE_COMPILATION_CACHE}/" ; \
	} >"${FISSILE_WORK_DIR}/rsync.log" 2>&1 &
endif

images: bosh-images docker-images

image-base:
	${GIT_ROOT}/make/image-base

bosh-images:
	${GIT_ROOT}/make/bosh-images

docker-images:
	${GIT_ROOT}/make/images docker build

build: images

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
	@echo "docker registry = '${IMAGE_REGISTRY}'"
	@echo "       for make = '${IMAGE_REGISTRY_MAKE}'"
	@echo "docker org      = '${IMAGE_ORG}'"
	@echo "hcf version     = '${BRANCH}'"
	@echo "hcf prefix      = '${IMAGE_PREFIX}'"

########## CONFIGURATION TARGETS ##########

generate: ucp mpc aws

ucp:
	${GIT_ROOT}/make/generate ucp

mpc:
	${GIT_ROOT}/make/generate mpc

aws:
	${GIT_ROOT}/make/generate aws

aws-proxy:
	${GIT_ROOT}/make/generate aws-proxy

########## DISTRIBUTION TARGETS ##########

dist: mpc-dist aws-dist

mpc-dist: mpc
	${GIT_ROOT}/make/package-terraform mpc

aws-dist: aws
	${GIT_ROOT}/make/package-terraform aws

aws-proxy-dist: aws-proxy
	$(call print_status, Package AWS with proxy terraform configuration for distribution)
	@base=$$(mktemp -d aws_XXXXXXXXXX) && \
	mkdir -p $$base/aws-proxy/terraform && \
	cp -rf container-host-files terraform/aws.tfvars.example terraform/aws-proxy.tf terraform/README-aws.md hcf-aws-proxy.tf.json $$base/aws-proxy/ && \
	cp terraform/proxy.conf terraform/proxy-setup.sh $$base/aws-proxy/terraform/ && \
	( cd $$base && zip -r9 ${CURDIR}/aws-proxy-$(APP_VERSION).zip aws-proxy ) && \
	rm -rf $$base && \
	echo Generated aws-proxy-$(APP_VERSION).zip

ENV_FILE := $(shell mktemp -q -u -t make.environ.XXXXXX)

.INTERMEDIATE: ${ENV_FILE}

${ENV_FILE}:
	cat /proc/self/environ > $@

mpc-terraform-tests: ${ENV_FILE}
	docker run --rm \
	  -v ${CURDIR}:${CURDIR} \
	  -v ${OS_SSH_KEY_PATH}:${OS_SSH_KEY_PATH}:ro \
	  -v ${ENV_FILE}:/environ:ro \
	  helioncf/terraform-tests \
	  ruby ${CURDIR}/bin/run-terraform-tests.rb
