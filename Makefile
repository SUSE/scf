#!/usr/bin/env make

# Default target specification
run:

CF_RELEASE ?= $(shell cat cf-release-version)
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
ENV_DIR        :=

# Note: When used the registry must not have a trailing "/". That is
# added automatically, see IMAGE_REGISTRY_MAKE for the make variable.
# Examples:
# - localhost:5000
# - docker.helion.lol

# Redefine the CI configuration variables, validation
IMAGE_ORG           := $(if ${IMAGE_ORG},${IMAGE_ORG},$(error Need a non-empty IMAGE_ORG))
IMAGE_PREFIX        := $(if ${IMAGE_PREFIX},${IMAGE_PREFIX},$(error Need a non-empty IMAGE_PREFIX))
IMAGE_REGISTRY_MAKE := $(if ${IMAGE_REGISTRY},"${IMAGE_REGISTRY}/",${IMAGE_REGISTRY})

# The variables are defaults; see bin/.fissilerc for defaults for the vagrant box
export FISSILE_RELEASE ?= ${CURDIR}/src/cf-release,${CURDIR}/src/cf-usb/cf-usb-release,${CURDIR}/src/diego-release,${CURDIR}/src/etcd-release,${CURDIR}/src/garden-linux-release,${CURDIR}/src/cf-mysql-release,${CURDIR}/src/hcf-deployment-hooks
export FISSILE_ROLES_MANIFEST ?= ${CURDIR}/container-host-files/etc/hcf/config/role-manifest.yml
export FISSILE_LIGHT_OPINIONS ?= ${CURDIR}/container-host-files/etc/hcf/config/opinions.yml
export FISSILE_DARK_OPINIONS ?= ${CURDIR}/container-host-files/etc/hcf/config/dark-opinions.yml
export FISSILE_DEV_CACHE_DIR ?= ${HOME}/.bosh/cache
export FISSILE_WORK_DIR ?= ${CURDIR}/_work

.PHONY: docker-images mpc mpc-dist aws aws-dist

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

registry:
	docker run -d -p 5000:5000 --restart=always --name registry registry:2

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
	for docker_role in $$(${CURDIR}/container-host-files/opt/hcf/bin/list-docker-roles.sh) ; do \
		cd ${CURDIR}/docker-images/$${docker_role} && \
		docker build -t $${docker_role}:${APP_VERSION_TAG} . ; \
	done

build: images

tag: bosh-tag docker-tag

bosh-tag:
	$(call print_status, Tagging bosh docker images)
	set -e ; \
	for source_image in $$(fissile dev list-roles); do \
	        component=$${source_image%:*} && \
	        component=$${component#fissile-} && \
	        echo Tagging $${source_image} && \
	        docker tag $${source_image} ${IMAGE_REGISTRY_MAKE}${IMAGE_ORG}/${IMAGE_PREFIX}-$${component}:${APP_VERSION_TAG} && \
	        docker tag $${source_image} ${IMAGE_REGISTRY_MAKE}${IMAGE_ORG}/${IMAGE_PREFIX}-$${component}:${BRANCH} ; \
	done

docker-tag:
	$(call print_status, Tagging docker images)
	set -e ; \
	for component in $$(${CURDIR}/container-host-files/opt/hcf/bin/list-docker-roles.sh); do \
	        source_image=$${component} && \
	        echo Tagging $${source_image} && \
	        docker tag $${source_image} ${IMAGE_REGISTRY_MAKE}${IMAGE_ORG}/${IMAGE_PREFIX}-$${component}:${APP_VERSION_TAG} && \
	        docker tag $${source_image} ${IMAGE_REGISTRY_MAKE}${IMAGE_ORG}/${IMAGE_PREFIX}-$${component}:${BRANCH} ; \
	done

publish: bosh-publish docker-publish

bosh-publish:
	$(call print_status, Publishing bosh docker images)
	set -e ; \
	for source_image in $$(fissile dev list-roles); do \
	        component=$${source_image%:*} && \
	        component=$${component#fissile-} && \
	        docker push ${IMAGE_REGISTRY_MAKE}${IMAGE_ORG}/${IMAGE_PREFIX}-$${component}:${APP_VERSION_TAG} && \
	        docker push ${IMAGE_REGISTRY_MAKE}${IMAGE_ORG}/${IMAGE_PREFIX}-$${component}:${BRANCH} ; \
	done

docker-publish:
	$(call print_status, Publishing docker images)
	set -e ; \
	for component in $$(${CURDIR}/container-host-files/opt/hcf/bin/list-docker-roles.sh); do \
	        docker push ${IMAGE_REGISTRY_MAKE}${IMAGE_ORG}/${IMAGE_PREFIX}-$${component}:${APP_VERSION_TAG} && \
	        docker push ${IMAGE_REGISTRY_MAKE}${IMAGE_ORG}/${IMAGE_PREFIX}-$${component}:${BRANCH} ; \
	done

show-docker-setup:
	@echo "docker registry = '${IMAGE_REGISTRY}'"
	@echo "       for make = '${IMAGE_REGISTRY_MAKE}'"
	@echo "docker org      = '${IMAGE_ORG}'"
	@echo "hcf version     = '${BRANCH}'"
	@echo "hcf prefix      = '${IMAGE_PREFIX}'"

########## CONFIGURATION TARGETS ##########

generate: ucp mpc aws

DTR := --dtr=${IMAGE_REGISTRY} --dtr-org=${IMAGE_ORG} --hcf-version=${BRANCH} --hcf-prefix=${IMAGE_PREFIX}
# Note, _not_ IMAGE_REGISTRY_MAKE. The rm-transformer script adds a trailing "/" itself, where needed

ucp:
	$(call print_status, Generate Helion UCP configuration)
	@docker run --rm \
	  -v ${CURDIR}:${CURDIR} \
	  helioncf/hcf-pipeline-ruby-bosh \
	  bash -l -c \
	  "rbenv global 2.2.3 && ${CURDIR}/bin/rm-transformer.rb ${DTR} --env "${ENV_DIR}" --provider ucp ${CURDIR}/container-host-files/etc/hcf/config/role-manifest.yml" > "${CURDIR}/hcf-ucp.json" ; \
	echo Generated ${CURDIR}/hcf-ucp.json

mpc:
	$(call print_status, Generate MPC terraform configuration)
	@docker run --rm \
	  -v ${CURDIR}:${CURDIR} \
	  helioncf/hcf-pipeline-ruby-bosh \
	  bash -l -c \
	  "rbenv global 2.2.3 && ${CURDIR}/bin/rm-transformer.rb ${DTR} --env "${ENV_DIR}" --provider tf ${CURDIR}/container-host-files/etc/hcf/config/role-manifest.yml ${CURDIR}/terraform/mpc.tf" > "${CURDIR}/hcf.tf" ; \
	echo Generated ${CURDIR}/hcf.tf

aws:
	$(call print_status, Generate AWS terraform configuration)
	@docker run --rm \
	  -v ${CURDIR}:${CURDIR} \
	  helioncf/hcf-pipeline-ruby-bosh \
	  bash -l -c \
	  "rbenv global 2.2.3 && ${CURDIR}/bin/rm-transformer.rb ${DTR} --env "${ENV_DIR}" --provider tf:aws ${CURDIR}/container-host-files/etc/hcf/config/role-manifest.yml ${CURDIR}/terraform/aws.tf" > "${CURDIR}/hcf-aws.tf" ; \
	echo Generated ${CURDIR}/hcf-aws.tf

########## DISTRIBUTION TARGETS ##########

dist: mpc-dist aws-dist

mpc-dist: mpc
	$(call print_status, Package MPC terraform configuration for distribution)
	@base=$$(mktemp -d mpc_XXXXXXXXXX) && \
	mkdir $$base/mpc && \
	cp -rf container-host-files terraform/mpc.tfvars.example terraform/README-mpc.md hcf.tf $$base/mpc/ && \
	( cd $$base && zip -qr9 ${CURDIR}/mpc-$(APP_VERSION).zip mpc ) && \
	rm -rf $$base && \
	echo Generated mpc-$(APP_VERSION).zip

aws-dist: aws
	$(call print_status, Package AWS terraform configuration for distribution)
	@base=$$(mktemp -d aws_XXXXXXXXXX) && \
	mkdir $$base/aws && \
	cp -rf container-host-files terraform/aws.tfvars.example terraform/README-aws.md hcf-aws.tf $$base/aws/ && \
	( cd $$base && zip -r9 ${CURDIR}/aws-$(APP_VERSION).zip aws ) && \
	rm -rf $$base && \
	echo Generated aws-$(APP_VERSION).zip
