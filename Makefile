#!/usr/bin/env make

# Default target specification
run:

CF_RELEASE ?= $(shell cat cf-release-version)
UBUNTU_IMAGE ?= ubuntu:14.04

include version.mk

IMAGE_PREFIX   := hcf
IMAGE_ORG      := helioncf
IMAGE_REGISTRY :=
# Note: When used the registry must include a trailing "/" for proper
# separation from the image path itself
# Examples:
# - localhost:5000/
# - docker.helion.lol/

BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
COMMIT := $(shell git describe --tags --long | sed -r 's/[0-9.]+-([0-9]+)-(g[a-f0-9]+)/\1.\2/')
APP_VERSION := ${VERSION}+${COMMIT}.${BRANCH}
APP_VERSION_TAG := $(subst +,_,${APP_VERSION})

# The variables are defaults; see bin/.fissilerc for defaults for the vagrant box
export FISSILE_RELEASE ?= ${CURDIR}/src/cf-release,${CURDIR}/src/cf-usb/cf-usb-release,${CURDIR}/src/diego-release,${CURDIR}/src/etcd-release,${CURDIR}/src/garden-linux-release,${CURDIR}/src/cf-mysql-release,${CURDIR}/src/hcf-deployment-hooks
export FISSILE_ROLES_MANIFEST ?= ${CURDIR}/container-host-files/etc/hcf/config/role-manifest.yml
export FISSILE_LIGHT_OPINIONS ?= ${CURDIR}/container-host-files/etc/hcf/config/opinions.yml
export FISSILE_DARK_OPINIONS ?= ${CURDIR}/container-host-files/etc/hcf/config/dark-opinions.yml
export FISSILE_DEV_CACHE_DIR ?= ${HOME}/.bosh/cache
export FISSILE_WORK_DIR ?= ${CURDIR}/_work

.PHONY: docker-images

########## UTILITY TARGETS ##########

print_status = @printf "\033[32;01m==> ${1}\033[0m\n"

clean:
	$(call print_status, Cleaning work directory)
	rm -rf ${FISSILE_WORK_DIR}

clean-harder: clean
	$(call print_status, Cleaning docker containers)
	-docker rm --force $(shell docker ps --all --quiet --filter=name=fissile-)

all: images tag terraform

fetch-submodules:
	git submodule update --init --recursive --depth=1 ${CURDIR}/src

print-version:
	@echo hcf-${APP_VERSION_TAG}

########## VAGRANT VM TARGETS ##########

run:
	$(call print_status, Running HCF ...)
	${CURDIR}/bin/run.sh

stop:
	$(call print_status, Stopping all HCF roles (this takes a while) ...)
	for r in $$(container-host-files/opt/hcf/bin/list-roles.sh) ; do container-host-files/opt/hcf/bin/stop-role.sh $$r ; done

vagrant-box:
	cd packer && \
	packer build vagrant-box.json

vagrant-prep: \
	compile-base \
	releases \
	compile \
	image-base \
	images \
	${NULL}

########## BOSH RELEASE TARGETS ##########

cf-release:
	$(call print_status, Creating cf-release BOSH release ... )
	${CURDIR}/bin/create-release.sh src/cf-release cf

usb-release:
	$(call print_status, Creating cf-usb BOSH release ... )
	${CURDIR}/bin/create-release.sh src/cf-usb/cf-usb-release cf-usb

diego-release:
	$(call print_status, Creating diego BOSH release ... )
	${CURDIR}/bin/create-release.sh src/diego-release diego

etcd-release:
	$(call print_status, Creating etcd BOSH release ... )
	${CURDIR}/bin/create-release.sh src/etcd-release etcd

garden-release:
	$(call print_status, Creating garden-linux BOSH release ... )
	${CURDIR}/bin/create-release.sh src/garden-linux-release garden-linux

mysql-release:
	$(call print_status, Creating cf-mysql-release BOSH release ... )
	${CURDIR}/bin/create-release.sh src/cf-mysql-release cf-mysql

hcf-deployment-hooks:
	$(call print_status, Creating hcf-deployment-hooks BOSH release ... )
	${CURDIR}/bin/create-release.sh src/hcf-deployment-hooks hcf-deployment-hooks

releases: cf-release usb-release diego-release etcd-release garden-release mysql-release hcf-deployment-hooks

########## FISSILE BUILD TARGETS ##########

compile-base:
	$(call print_status, Compiling build base image)
	fissile compilation build-base --base-image ${UBUNTU_IMAGE}

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
		rsync -rl --include="/*/" --include="/*/*/" --include="/*/*/compiled.tar" --exclude="*" --info=progress2 "${FISSILE_WORK_DIR}/compilation/" "${HCF_PACKAGE_COMPILATION_CACHE}/" ; \
	} >"${FISSILE_WORK_DIR}/rsync.log" 2>&1 &
endif

images: bosh-images docker-images

image-base:
	$(call print_status, Creating BOSH role base image)
	fissile images create-base --base-image ${UBUNTU_IMAGE}

bosh-images:
	$(call print_status, Building BOSH role images)
	fissile dev create-images

docker-images:
	$(call print_status, Building Docker role images)
	for docker_role in $$(bash -c "source ${CURDIR}/container-host-files/opt/hcf/bin/common.sh && load_all_roles && list_all_docker_roles") ; do \
		cd ${CURDIR}/docker-images/$${docker_role} && \
		docker build -t $${docker_role}:${APP_VERSION_TAG} . ; \
	done

build: images

tag:
	$(call print_status, Tagging docker images)
	set -e ; \
	for source_image in $$(fissile dev list-roles); do \
	        component=$${source_image%:*} && \
	        component=$${component#fissile-} && \
	        docker tag $${source_image} ${IMAGE_REGISTRY}${IMAGE_ORG}/${IMAGE_PREFIX}-$${component}:${APP_VERSION_TAG} && \
	        docker tag $${source_image} ${IMAGE_REGISTRY}${IMAGE_ORG}/${IMAGE_PREFIX}-$${component}:${BRANCH} ; \
	done

publish:
	$(call print_status, Publishing docker images)
	set -e ; \
	for source_image in $$(fissile dev list-roles); do \
	        component=$${source_image%:*} && \
	        component=$${component#fissile-} && \
	        docker push ${IMAGE_REGISTRY}${IMAGE_ORG}/${IMAGE_PREFIX}-$${component}:${APP_VERSION_TAG} && \
	        docker push ${IMAGE_REGISTRY}${IMAGE_ORG}/${IMAGE_PREFIX}-$${component}:${BRANCH} ; \
	done

DIST_DIR := ${FISSILE_WORK_DIR}/hcf/terraform-scripts/
terraform:
	mkdir -p ${DIST_DIR}/direct_internet
	mkdir -p ${DIST_DIR}/proxied_internet
	mkdir -p ${DIST_DIR}/templates

	cp -rL ${CURDIR}/terraform-scripts/hcf/* ${DIST_DIR}/direct_internet/
	cp -rL ${CURDIR}/terraform-scripts/hcf-proxied/* ${DIST_DIR}/proxied_internet/
	cp -rL ${CURDIR}/terraform-scripts/templates/* ${DIST_DIR}/templates/

	cp -rL ${CURDIR}/container-host-files ${FISSILE_WORK_DIR}/hcf/

	echo "variable \"build\" {\n\tdefault = \"${APP_VERSION}\"\n}\n" > ${DIST_DIR}/direct_internet/version.tf
	echo "variable \"build\" {\n\tdefault = \"${APP_VERSION}\"\n}\n" > ${DIST_DIR}/proxied_internet/version.tf

	tar -chzvf ${FISSILE_WORK_DIR}/hcf-${APP_VERSION}.tar.gz -C ${FISSILE_WORK_DIR} hcf

generate: rm2ucp rm2mpc

rm2ucp:
	./bin/rm-transformer.rb --provider ucp \
		${FISSILE_ROLES_MANIFEST} \
		> ${CURDIR}/ucp.json

rm2mpc:
	./bin/rm-transformer.rb --provider tf \
		${FISSILE_ROLES_MANIFEST} ${CURDIR}/terraform/mpc.tf \
		> ${CURDIR}/hcf.tf
