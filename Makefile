NO_COLOR=\033[0m
OK_COLOR=\033[32;01m
ERROR_COLOR=\033[31;01m
WARN_COLOR=\033[33;01m

OS_TYPE?=$(shell uname | tr '[:upper:]' '[:lower:]')
CF_RELEASE?=$(shell cat cf-release-version)
CF_RELEASE_LOCATION?=https://bosh.io/d/github.com/cloudfoundry/cf-release?v=${CF_RELEASE}

WORK_DIR?=${PWD}/_work
RELEASE_DIR=${WORK_DIR}/release
REPOSITORY=${fissile}

UBUNTU_IMAGE=ubuntu:14.04.2

COMPONENTS=uaa stats runner router postgres nats loggregator_trafficcontroller hm9000 ha_proxy etcd doppler consul clock_global api_worker api smoke_tests acceptance_tests

include version.mk

BRANCH=$(shell git rev-parse --abbrev-ref HEAD)
BUILD:=$(shell whoami)-${BRANCH}-$(shell date -u +%Y%m%d%H%M%S)
APP_VERSION=${VERSION}-${BUILD}

FISSILE_BRANCH:=${BRANCH}
CONFIGGIN_BRANCH:=${BRANCH}

SETUP=${WORK_DIR}/hcf ${WORK_DIR}/targets/.ubuntu_image ${WORK_DIR}/fissile

all: generate_config_base images publish_images dist

.PHONY: all clean clean_targets tools phony

clean:
	@echo "${OK_COLOR}==> Cleaning${NO_COLOR}"
	rm -rf ${WORK_DIR}
	-docker rm --force $(shell docker ps -a | grep fissile | cut -f1 -d' ')

clean_targets:
	-rm -fr ${WORK_DIR}/targets/.* ${WORK_DIR}/targets/*

${WORK_DIR}/targets/.ubuntu_image: ${WORK_DIR}/targets
	docker pull ${UBUNTU_IMAGE}
	touch ${WORK_DIR}/targets/.ubuntu_image

${WORK_DIR}/hcf ${WORK_DIR}/targets:
	mkdir -p $@

${WORK_DIR}/fissile:
	@echo "${OK_COLOR}==> Looking up latest fissile build${NO_COLOR}"
	# Find the latest artifact, excluding the babysitter builds
	# This looks inside the swift container, filtering by your OS type, sorts in ascending order and takes the last entry
	# If we were to write a "latest" link, this would be easier.
	@echo "If swift download fails get fissile and fissile-artificats from jenkins and manually place in ${WORK_DIR}"
	$(eval LATEST_FISSILE_BUILD="$(shell swift list -l fissile-artifacts | grep -v babysitter | grep \\_${FISSILE_BRANCH}/ | grep ${OS_TYPE} | cut -c 14-33,34- | sort | tail -1)")
	swift download --output ${WORK_DIR}/fissile fissile-artifacts $(shell echo ${LATEST_FISSILE_BUILD} | cut -c 21-)
	chmod +x ${WORK_DIR}/fissile

${WORK_DIR}/configgin.tar.gz: ${SETUP} 
	@echo "${OK_COLOR}==> Looking up latest configgin build${NO_COLOR}"
	$(eval LATEST_CONFIGGIN_BUILD="$(shell swift list -l configgin | grep \\_${CONFIGGIN_BRANCH}/ | grep -v babysitter | grep linux-x86_64.tgz | cut -c 14-33,34- | sort | tail -1)")
	@echo "If swift download fails get configging from jenkins and manually place in ${WORK_DIR}"
	swift download --output ${WORK_DIR}/configgin.tar.gz configgin $(shell echo ${LATEST_CONFIGGIN_BUILD} | cut -c 21-)

images: ${SETUP} ${WORK_DIR}/configgin.tar.gz 
	@echo "${OK_COLOR}==> Build all Docker images${NO_COLOR}"
	make -C docker-images all APP_VERSION=${APP_VERSION} BRANCH=${BRANCH} BUILD=${BUILD}

# intentionally not contained in the normal build workflow - this is used
# so that we can fetch and cache a cf-release when we update to a new build.
fetch_new_cf_release: ${WORK_DIR}/cf-release-v${CF_RELEASE}.tar.gz
	@echo "${OK_COLOR}==> Fetching cf-release-${CF_RELEASE} from bosh.io${NO_COLOR}"

	curl -L "${CF_RELEASE_LOCATION}" -o ${WORK_DIR}/cf-release-v${CF_RELEASE}.tar.gz

	@echo "${OK_COLOR}==> Uploading cf-release-${CF_RELEASE} to Swift${NO_COLOR}"
	cd ${WORK_DIR} ; swift upload cf-release cf-release-v${CF_RELEASE}.tar.gz

fetch_cf_release: ${WORK_DIR}/cf-release.tar.gz

${WORK_DIR}/cf-release.tar.gz:
	@echo "${OK_COLOR}==> Fetching cf-release-${CF_RELEASE} from Swift${NO_COLOR}"
	@echo "If swift download fails get cf-release-v${CF_RELEASE}.tar.gz and manually place in ${WORK_DIR}"
	swift download cf-release cf-release-v${CF_RELEASE}.tar.gz -o ${WORK_DIR}/cf-release.tar.gz
	mkdir -p ${RELEASE_DIR} && cd ${RELEASE_DIR} && tar zxf ../cf-release.tar.gz

compile_base: ${WORK_DIR}/targets/.compiled_base

${WORK_DIR}/targets/.compiled_base: ${WORK_DIR}/targets
	@echo "${OK_COLOR}==> Compiling base image for cf-release${NO_COLOR}"
	-docker rm fissile-cf-${CF_RELEASE}-cbase
	-docker rmi fissile:cf-${CF_RELEASE}-cbase

	_work/fissile compilation build-base -b ${UBUNTU_IMAGE} -p ${REPOSITORY}
	touch ${WORK_DIR}/targets/.compiled_base

compile_release: compile_base ${WORK_DIR}/targets/.compiled_release

${WORK_DIR}/targets/.compiled_release:
	@echo "${OK_COLOR}==> Compiling cf-release${NO_COLOR}"
	_work/fissile compilation start -r ${RELEASE_DIR} -t ${WORK_DIR}/compile_target -p ${REPOSITORY}
	touch ${WORK_DIR}/targets/.compiled_release

base_image: compile_release ${WORK_DIR}/configgin.tar.gz ${WORK_DIR}/targets/.base_image

${WORK_DIR}/targets/.base_image:
	_work/fissile images create-base -t ${WORK_DIR}/base_image -c ${WORK_DIR}/configgin.tar.gz -b ${UBUNTU_IMAGE} -p ${REPOSITORY}
	touch ${WORK_DIR}/targets/.base_image

compile_images: base_image ${WORK_DIR}/targets/.compile_images

${WORK_DIR}/targets/.compile_images:
	_work/fissile images create-roles -t ${WORK_DIR}/images -r ${RELEASE_DIR} -m ${PWD}/config-opinions/cf-v${CF_RELEASE}/role-manifest.yml -c ${WORK_DIR}/compile_target -v ${APP_VERSION} -p ${REPOSITORY}
	touch ${WORK_DIR}/targets/.compile_images

# fetch_cf_release
generate_config_base: ${WORK_DIR}/targets/.config_target

${WORK_DIR}/targets/.config_target:
	rm -rf ${WORK_DIR}/config_target
	_work/fissile configuration generate \
		-r ${RELEASE_DIR} \
		--light-opinions config-opinions/cf-v${CF_RELEASE}/opinions.yml \
		--dark-opinions config-opinions/cf-v${CF_RELEASE}/dark-opinions.yml \
		--target ${WORK_DIR}/config_target
	cd ${WORK_DIR}/config_target ; tar czf ${WORK_DIR}/hcf-config.tar.gz hcf/
	touch ${WORK_DIR}/targets/.config_target

publish_images: compile_images
	for component in ${COMPONENTS}; do \
		docker tag -f fissile-$$component:${CF_RELEASE}-${APP_VERSION} helioncf/cf-$$component:${APP_VERSION} && \
		docker tag -f fissile-$$component:${CF_RELEASE}-${APP_VERSION} helioncf/cf-$$component:latest-${BRANCH} && \
		docker push helioncf/cf-$$component:${APP_VERSION} && \
		docker push helioncf/cf-$$component:latest-${BRANCH} ; \
	done

dist: generate_config_base
	cd ${WORK_DIR}/hcf && mkdir -p terraform-scripts/direct_internet && cp -r ${PWD}/terraform-scripts/hcf/* terraform-scripts/direct_internet/
	cd ${WORK_DIR}/hcf && mkdir -p terraform-scripts/proxied_internet && cp -r ${PWD}/terraform-scripts/hcf-proxied/* terraform-scripts/proxied_internet/
	cd ${WORK_DIR}/hcf && mkdir -p terraform-scripts/templates && cp -r ${PWD}/terraform-scripts/templates/* terraform-scripts/templates/
	cp -r ${PWD}/container-host-files ${WORK_DIR}/hcf/

	cp ${WORK_DIR}/hcf-config.tar.gz ${WORK_DIR}/hcf/terraform-scripts/direct_internet/
	cp ${WORK_DIR}/hcf-config.tar.gz ${WORK_DIR}/hcf/terraform-scripts/proxied_internet/

	cd ${WORK_DIR}/hcf ; echo "variable \"build\" {\n\tdefault = \"${APP_VERSION}\"\n}\n" > terraform-scripts/direct_internet/version.tf
	cd ${WORK_DIR}/hcf ; echo "variable \"build\" {\n\tdefault = \"${APP_VERSION}\"\n}\n" > terraform-scripts/proxied_internet/version.tf

	cd ${WORK_DIR} ; tar -chzvf ${WORK_DIR}/hcf-${APP_VERSION}.tar.gz ./hcf

# --- NEW STUFF ---

vagrant_box:
	cd packer && packer build vagrant-box.json

cf_release:
	@echo "${OK_COLOR}==> Running bosh create release for cf-release ... ${NO_COLOR}"
	cd ${PWD}/src/cf-release && \
	bosh create release --force --name cf

cf_usb_release:
	@echo "${OK_COLOR}==> Running bosh create release for cf-usb ... ${NO_COLOR}"
	cd ${PWD}/src/cf-usb/cf-usb-release && \
	bosh create release --force --name cf-usb

releases: cf_release cf_usb_release
	@echo "${OK_COLOR}==> Creating BOSH releases ... ${NO_COLOR}"

fissile_compilation_base:
	@echo "${OK_COLOR}==> Building compilation base ... ${NO_COLOR}"
	fissile compilation build-base

fissile_compile_packages: fissile_create_config fissile_compilation_base
	@echo "${OK_COLOR}==> Compiling packages from all releases ... ${NO_COLOR}"
	mkdir -p "${HCF_PACKAGE_COMPILATION_CACHE}/" && \
	mkdir -p "${FISSILE_COMPILATION_DIR}/" && \
	rsync -a "${HCF_PACKAGE_COMPILATION_CACHE}/" "${FISSILE_COMPILATION_DIR}/" && \
	fissile dev compile && \
	rsync -a "${FISSILE_COMPILATION_DIR}/" "${HCF_PACKAGE_COMPILATION_CACHE}/"

fissile_create_base:
	@echo "${OK_COLOR}==> Creating image base ... ${NO_COLOR}"
	fissile images create-base

fissile_create_images: fissile_create_base fissile_compile_packages
	@echo "${OK_COLOR}==> Creating docker images ... ${NO_COLOR}"
	fissile dev create-images

fissile_create_config: releases
	@echo "${OK_COLOR}==> Generating configuration ... ${NO_COLOR}"
	fissile dev config-gen

docker_images:
	@echo "${OK_COLOR}==> Build all Docker images${NO_COLOR}"
	make -C docker-images build APP_VERSION=${APP_VERSION} BRANCH=${BRANCH} BUILD=${BUILD}

tag_images: docker_images fissile_create_images
	make -C docker-images tag APP_VERSION=${APP_VERSION} BRANCH=${BRANCH} BUILD=${BUILD} && \
	for image in $(shell fissile dev lr); do \
		role_name=`bash -c "source ${PWD}/container-host-files/opt/hcf/bin/common.sh; get_role_name $$image"` ; \
		docker tag -f $$image ${REGISTRY_HOST}/hcf/hcf-$$role_name:${APP_VERSION} ; \
		docker tag -f $$image ${REGISTRY_HOST}/hcf/hcf-$$role_name:latest-${BRANCH} ; \
	done

push_images: tag_images
	make -C docker-images push APP_VERSION=${APP_VERSION} BRANCH=${BRANCH} BUILD=${BUILD} && \
	for image in $(shell fissile dev lr); do \
		role_name=`bash -c "source ${PWD}/container-host-files/opt/hcf/bin/common.sh; get_role_name $$image"` ; \
		docker push ${REGISTRY_HOST}/hcf/hcf-$$role_name:${APP_VERSION} ; \
		docker push ${REGISTRY_HOST}/hcf/hcf-$$role_name:latest-${BRANCH} ; \
	done

clean_out:
	@echo "${OK_COLOR}==> Cleaning${NO_COLOR}"
	rm -rf ${WORK_DIR}

setup_out: clean_out
	@echo "${OK_COLOR}==> Setup${NO_COLOR}"
	mkdir -p ${WORK_DIR}
	mkdir -p ${WORK_DIR}/hcf

create_dist: fissile_create_config setup_out
	cd ${FISSILE_CONFIG_OUTPUT_DIR} ; tar czf ${WORK_DIR}/hcf-config.tar.gz hcf/
	cd ${WORK_DIR}/hcf ; cp -r ${PWD}/terraform-scripts . ; cp -r ${PWD}/container-host-files .
	mv ${WORK_DIR}/hcf/terraform-scripts/hcf ${WORK_DIR}/hcf/terraform-scripts/direct_internet
	mv ${WORK_DIR}/hcf/terraform-scripts/hcf-proxied ${WORK_DIR}/hcf/terraform-scripts/proxied_internet
	cd ${WORK_DIR}/hcf/terraform-scripts/direct_internet ; cp ${WORK_DIR}/hcf-config.tar.gz . ; echo "variable \"build\" {\n\tdefault = \"${APP_VERSION}\"\n}\n" > version.tf
	cd ${WORK_DIR}/hcf/terraform-scripts/proxied_internet ; cp ${WORK_DIR}/hcf-config.tar.gz . ; echo "variable \"build\" {\n\tdefault = \"${APP_VERSION}\"\n}\n" > version.tf
	cd ${WORK_DIR} ; tar -chzvf ${WORK_DIR}/hcf-${APP_VERSION}.tar.gz ./hcf

release: push_images create_dist

stop:
	@echo "${OK_COLOR}==> Stopping all HCF roles (this takes a while) ...${NO_COLOR}"
	docker rm -f $(shell fissile dev lr | sed -e 's/:/-/g')

run: docker_images fissile_create_config fissile_create_images
	@echo "${OK_COLOR}==> Running HCF ... ${NO_COLOR}"
	${PWD}/bin/run.sh
