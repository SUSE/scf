#!/usr/bin/env make

# Default target specification
run:

CF_RELEASE ?= $(shell cat cf-release-version)
UBUNTU_IMAGE ?= ubuntu:14.04
WORK_DIR := ${CURDIR}/_work

include version.mk

BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
COMMIT := $(shell git describe --tags --long | sed -r 's/[0-9.]+-([0-9]+)-(g[a-f0-9]+)/\1.\2/')
APP_VERSION := ${VERSION}+${COMMIT}.${BRANCH}
APP_VERSION_TAG := $(subst +,_,${APP_VERSION})

# The variables are defaults; see bin/.fissilerc for defaults for the vagrant box
export FISSILE_RELEASE ?= ${CURDIR}/src/cf-release,${CURDIR}/src/cf-usb/cf-usb-release,${CURDIR}/src/diego-release,${CURDIR}/src/etcd-release,${CURDIR}/src/garden-linux-release
export FISSILE_ROLES_MANIFEST ?= ${CURDIR}/config-opinions/cf-v${CF_RELEASE}/role-manifest.yml
export FISSILE_LIGHT_OPINIONS ?= ${CURDIR}/config-opinions/cf-v${CF_RELEASE}/opinions.yml
export FISSILE_DARK_OPINIONS ?= ${CURDIR}/config-opinions/cf-v${CF_RELEASE}/dark-opinions.yml
export FISSILE_DEV_CACHE_DIR ?= ${HOME}/.bosh/cache
export FISSILE_WORK_DIR ?= ${WORK_DIR}

########## UTILITY TARGETS ##########

print_status = @printf "\033[32;01m==> ${1}\033[0m\n"

clean:
	$(call print_status, Cleaning work directory)
	rm -rf ${WORK_DIR}

clean-harder: clean
	$(call print_status, Cleaning docker containers)
	-docker rm --force $(shell docker ps --all --quiet --filter=name=fissile-)

all: images tag terraform

fetch-submodules:
	git submodule update --init --recursive --depth=1 ${CURDIR}/src

print-version:
	@echo hcf-${APP_VERSION_TAG}

########## VAGRANT VM TARGETS ##########

run: ${WORK_DIR}/hcf-config.tar.gz
	$(call print_status, Running HCF ...)
	${CURDIR}/bin/run.sh

stop:
	$(call print_status, Stopping all HCF roles (this takes a while) ...)
	docker rm -f $(shell fissile dev list-roles | tr : -)

vagrant-box:
	cd packer && \
	packer build vagrant-box.json

vagrant-prep: \
	compile-base \
	releases \
	configs \
	compile \
	image-base \
	images \
	${NULL}

########## BOSH RELEASE TARGETS ##########

cf-release:
	$(call print_status, Creating cf-release BOSH release ... )
	bosh create release --dir ${CURDIR}/src/cf-release --force --name cf

usb-release:
	$(call print_status, Creating cf-usb BOSH release ... )
	bosh create release --dir ${CURDIR}/src/cf-usb/cf-usb-release --force --name cf-usb

diego-release:
	$(call print_status, Creating diego BOSH release ... )
	bosh create release --dir ${CURDIR}/src/diego-release --force --name diego

etcd-release:
	$(call print_status, Creating etcd BOSH release ... )
	bosh create release --dir ${CURDIR}/src/etcd-release --force --name etcd

garden-release:
	$(call print_status, Creating garden-linux BOSH release ... )
	bosh create release --dir ${CURDIR}/src/garden-linux-release --force --name garden-linux

releases: cf-release usb-release diego-release etcd-release garden-release

########## FISSILE BUILD TARGETS ##########

configs: ${WORK_DIR}/hcf-config.tar.gz

${WORK_DIR}/hcf-config.tar.gz:
	$(call print_status, Generating configuration)
	fissile dev config-gen
	tar czf $@ -C ${FISSILE_WORK_DIR}/config/ hcf/

compile-base:
	$(call print_status, Compiling build base image)
	fissile compilation build-base --base-image ${UBUNTU_IMAGE}

compile: ${WORK_DIR}/hcf-config.tar.gz
	$(call print_status, Compiling BOSH release packages)
	mkdir -p "${FISSILE_WORK_DIR}/compilation/"
	if [ -n "${HCF_PACKAGE_COMPILATION_CACHE}" ] ; then \
		mkdir -p "${HCF_PACKAGE_COMPILATION_CACHE}" ; \
		rsync -a --info=progress2 "${HCF_PACKAGE_COMPILATION_CACHE}/" "${FISSILE_WORK_DIR}/compilation/" ; \
	fi
	fissile dev compile
	if [ -n "${HCF_PACKAGE_COMPILATION_CACHE}" ] ; then \
		rsync -a --info=progress2 "${FISSILE_WORK_DIR}/compilation/" "${HCF_PACKAGE_COMPILATION_CACHE}/" ; \
	fi

images: bosh-images hcf-images

image-base:
	$(call print_status, Creating BOSH role base image)
	fissile images create-base --base-image ${UBUNTU_IMAGE}

bosh-images:
	$(call print_status, Building BOSH role images)
	fissile dev create-images

hcf-images:
	$(call print_status, Building HCF docker images)
	${MAKE} -C docker-images build

build: configs images

tag:
	$(call print_status, Tagging docker images)
	make -C docker-images tag
	set -e ; \
	for source_image in $$(fissile dev list-roles); do \
		component=$${source_image%:*} && \
		component=$${component#fissile-} && \
		docker tag -f $${source_image} helioncf/cf-$${component}:${APP_VERSION_TAG} && \
		docker tag -f $${source_image} helioncf/cf-$${component}:latest-${BRANCH} ; \
	done

publish:
	$(call print_status, Publishing docker images)
	make -C docker-images push
	set -e ; \
	for source_image in $$(fissile dev list-roles); do \
		component=$${source_image%:*} && \
		component=$${component#fissile-} && \
		docker push helioncf/cf-$${component}:${APP_VERSION_TAG} && \
		docker push helioncf/cf-$${component}:latest-${BRANCH} ; \
	done

DIST_DIR := ${WORK_DIR}/hcf/terraform-scripts/
terraform: ${WORK_DIR}/hcf-config.tar.gz
	mkdir -p ${DIST_DIR}/direct_internet
	mkdir -p ${DIST_DIR}/proxied_internet
	mkdir -p ${DIST_DIR}/templates

	cp -rL ${CURDIR}/terraform-scripts/hcf/* ${DIST_DIR}/direct_internet/
	cp -rL ${CURDIR}/terraform-scripts/hcf-proxied/* ${DIST_DIR}/proxied_internet/
	cp -rL ${CURDIR}/terraform-scripts/templates/* ${DIST_DIR}/templates/

	cp -rL ${CURDIR}/container-host-files ${WORK_DIR}/hcf/

	cp ${WORK_DIR}/hcf-config.tar.gz ${DIST_DIR}/direct_internet/
	cp ${WORK_DIR}/hcf-config.tar.gz ${DIST_DIR}/proxied_internet/

	echo "variable \"build\" {\n\tdefault = \"${APP_VERSION}\"\n}\n" > ${DIST_DIR}/direct_internet/version.tf
	echo "variable \"build\" {\n\tdefault = \"${APP_VERSION}\"\n}\n" > ${DIST_DIR}/proxied_internet/version.tf

	tar -chzvf ${WORK_DIR}/hcf-${APP_VERSION}.tar.gz -C ${WORK_DIR} hcf
