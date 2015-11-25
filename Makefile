NO_COLOR=\033[0m
OK_COLOR=\033[32;01m
ERROR_COLOR=\033[31;01m
WARN_COLOR=\033[33;01m

OS_TYPE?=$(shell uname | tr '[:upper:]' '[:lower:]')
CF_RELEASE?=$(shell cat cf-release-version)
CF_RELEASE_LOCATION?=https://bosh.io/d/github.com/cloudfoundry/cf-release?v=$(CF_RELEASE)

WORK_DIR=$(PWD)/_work
RELEASE_DIR=$(WORK_DIR)/release
TARGET_DIR=$(PWD)/target

UBUNTU_IMAGE=ubuntu:14.04.2

COMPONENTS=uaa stats runner router postgres nats loggregator_trafficcontroller hm9000 ha_proxy etcd doppler consul clock_global api_worker api smoke_tests acceptance_tests

include version.mk

BRANCH=$(shell git rev-parse --abbrev-ref HEAD)
BUILD:=$(shell whoami)-$(BRANCH)-$(shell date -u +%Y%m%d%H%M%S)
APP_VERSION=$(VERSION)-$(BUILD)

FISSILE_BRANCH:=$(BRANCH)
CONFIGGIN_BRANCH:=$(BRANCH)
GATO_BRANCH:=$(BRANCH)

all: generate_config_base dist images publish_images

.PHONY: all clean setup tools fetch_fissle phony

clean:
	@echo "$(OK_COLOR)==> Cleaning$(NO_COLOR)"
	rm -rf $(WORK_DIR) $(TARGET_DIR)
	-docker rm --force $(shell docker ps -a | grep fissile | cut -f1 -d' ')

setup:
	@echo "$(OK_COLOR)==> Setup$(NO_COLOR)"
	mkdir -p $(TARGET_DIR)
	mkdir -p $(WORK_DIR)
	mkdir -p $(WORK_DIR)/hcf
	docker pull $(UBUNTU_IMAGE)

fetch_fissle: setup
	@echo "$(OK_COLOR)==> Looking up latest fissile build$(NO_COLOR)"
	# Find the latest artifact, excluding the babysitter builds
	# This looks inside the swift container, filtering by your OS type, sorts in ascending order and takes the last entry
	# If we were to write a "latest" link, this would be easier.
	$(eval LATEST_FISSILE_BUILD="$(shell swift list -l fissile-artifacts | grep -v babysitter | grep \\_$(FISSILE_BRANCH)/ | grep $(OS_TYPE) | cut -c 14-33,34- | sort | tail -1)")

	swift download --output $(WORK_DIR)/fissile fissile-artifacts $(shell echo $(LATEST_FISSILE_BUILD) | cut -c 21-)
	chmod +x $(WORK_DIR)/fissile

fetch_configgin: setup
	@echo "$(OK_COLOR)==> Looking up latest configgin build$(NO_COLOR)"

	$(eval LATEST_CONFIGGIN_BUILD="$(shell swift list -l configgin | grep \\_$(CONFIGGIN_BRANCH)/ | grep -v babysitter | grep linux-x86_64.tgz | cut -c 14-33,34- | sort | tail -1)")
	swift download --output $(WORK_DIR)/configgin.tar.gz configgin $(shell echo $(LATEST_CONFIGGIN_BUILD) | cut -c 21-)

tools: fetch_fissle fetch_configgin
	$(WORK_DIR)/fissile

images: setup tools
	@echo "$(OK_COLOR)==> Build all Docker images$(NO_COLOR)"
	make -C images all APP_VERSION=$(APP_VERSION) BRANCH=$(BRANCH) BUILD=$(BUILD)

# intentionally not contained in the normal build workflow - this is used
# so that we can fetch and cache a cf-release when we update to a new build.
fetch_new_cf_release:
	@echo "$(OK_COLOR)==> Fetching cf-release-$(CF_RELEASE) from bosh.io$(NO_COLOR)"

	curl -L "$(CF_RELEASE_LOCATION)" -o $(WORK_DIR)/cf-release-v$(CF_RELEASE).tar.gz

	@echo "$(OK_COLOR)==> Uploading cf-release-$(CF_RELEASE) to Swift$(NO_COLOR)"
	cd $(WORK_DIR) ; swift upload cf-release cf-release-v$(CF_RELEASE).tar.gz

fetch_cf_release: fetch_fissle
	@echo "$(OK_COLOR)==> Fetching cf-release-$(CF_RELEASE) from Swift$(NO_COLOR)"

	swift download cf-release cf-release-v$(CF_RELEASE).tar.gz -o $(WORK_DIR)/cf-release.tar.gz
	mkdir -p $(RELEASE_DIR) && cd $(RELEASE_DIR) && tar zxf ../cf-release.tar.gz

compile_base: fetch_cf_release fetch_configgin
	@echo "$(OK_COLOR)==> Compiling base image for cf-release$(NO_COLOR)"
	-docker rm fissile-cf-$(CF_RELEASE)-cbase
	-docker rmi fissile:cf-$(CF_RELEASE)-cbase

	_work/fissile compilation build-base -b $(UBUNTU_IMAGE)

compile_release: compile_base
	@echo "$(OK_COLOR)==> Compiling cf-release$(NO_COLOR)"
	_work/fissile compilation start -r $(RELEASE_DIR) -t $(WORK_DIR)/compile_target

base_image: compile_release
	_work/fissile images create-base -t $(WORK_DIR)/base_image -c $(WORK_DIR)/configgin.tar.gz -b $(UBUNTU_IMAGE)

compile_images: base_image
	_work/fissile images create-roles -t $(WORK_DIR)/images -r $(RELEASE_DIR) -m $(PWD)/config-opinions/cf-v$(CF_RELEASE)/role-manifest.yml -c $(WORK_DIR)/compile_target -v $(APP_VERSION)

generate_config_base: fetch_fissle fetch_cf_release
	rm -rf $(WORK_DIR)/config_target

	_work/fissile configuration generate \
		-r $(RELEASE_DIR) \
		--light-opinions config-opinions/cf-v$(CF_RELEASE)/opinions.yml \
		--dark-opinions config-opinions/cf-v$(CF_RELEASE)/dark-opinions.yml \
		--target $(WORK_DIR)/config_target

	cd $(WORK_DIR)/config_target ; tar czf $(WORK_DIR)/hcf-config.tar.gz hcf/

publish_images: compile_images
	for component in $(COMPONENTS); do \
		docker tag -f fissile-$$component:$(CF_RELEASE)-$(APP_VERSION) helioncf/cf-$$component:$(APP_VERSION) && \
		docker tag -f fissile-$$component:$(CF_RELEASE)-$(APP_VERSION) helioncf/cf-$$component:latest-$(BRANCH) && \
		docker push helioncf/cf-$$component:$(APP_VERSION) && \
		docker push helioncf/cf-$$component:latest-$(BRANCH) ; \
	done

dist: generate_config_base
	@echo "Pulling gato to ensure we have the latest build"
	docker pull helioncf/hcf-gato:latest-$(GATO_BRANCH)
	$(eval LATEST_GATO_BUILD="$(shell docker run -t helioncf/hcf-gato:latest-$(GATO_BRANCH) --version | sed 's/gato version //')")

	@echo "Built with fissile version $(LATEST_FISSILE_BUILD)"
	@echo "Packaging with gato version $(LATEST_GATO_BUILD)"
	@echo "Packaging with configgin version $(LATEST_CONFIGGIN_BUILD)"

	cd $(WORK_DIR)/hcf && mkdir -p direct_internet && cp -rL $(PWD)/terraform-scripts/hcf/* direct_internet/
	cd $(WORK_DIR)/hcf && mkdir -p proxied_internet && cp -rL $(PWD)/terraform-scripts/hcf-proxied/* proxied_internet/

	cp $(WORK_DIR)/hcf-config.tar.gz $(WORK_DIR)/hcf/direct_internet/
	cp $(WORK_DIR)/hcf-config.tar.gz $(WORK_DIR)/hcf/proxied_internet/

	cd $(WORK_DIR)/hcf ; echo "variable \"build\" {\n\tdefault = \"$(APP_VERSION)\"\n}\n\nvariable \"gato-build\" {\n\tdefault = \"$(LATEST_GATO_BUILD)\"\n}\n" > direct_internet/version.tf
	cd $(WORK_DIR)/hcf ; echo "variable \"build\" {\n\tdefault = \"$(APP_VERSION)\"\n}\n\nvariable \"gato-build\" {\n\tdefault = \"$(LATEST_GATO_BUILD)\"\n}\n" > proxied_internet/version.tf

	cd $(WORK_DIR) ; tar -chzvf $(WORK_DIR)/hcf-$(APP_VERSION).tar.gz ./hcf

# --- NEW STUFF ---
cf_release:
	@echo "$(OK_COLOR)==> Running bosh create release for cf-release ... $(NO_COLOR)"
	cd $(PWD)/src/cf-release && \
	bosh create release --force --name cf

releases: cf_release
	@echo "$(OK_COLOR)==> Creating BOSH releases ... $(NO_COLOR)"

fissile_compilation_base:
	@echo "$(OK_COLOR)==> Building compilation base ... $(NO_COLOR)"
	fissile compilation build-base

fissile_compile_packages: releases fissile_compilation_base
	@echo "$(OK_COLOR)==> Compiling packages from all releases ... $(NO_COLOR)"
	fissile dev compile

fissile_create_base:
	@echo "$(OK_COLOR)==> Creating image base ... $(NO_COLOR)"
	fissile images create-base

fissile_create_images: fissile_create_base fissile_compile_packages
	@echo "$(OK_COLOR)==> Creating docker images ... $(NO_COLOR)"
	fissile dev create-images

fissile_create_config:
	@echo "$(OK_COLOR)==> Generating configuration ... $(NO_COLOR)"
	fissile dev config-gen

docker_images:
	@echo "$(OK_COLOR)==> Build all Docker images$(NO_COLOR)"
	make -C images build APP_VERSION=$(APP_VERSION) BRANCH=$(BRANCH) BUILD=$(BUILD)

run_hcf_consul: docker_images

run: run_hcf_consul fissile_create_config fissile_create_images
	@echo "$(OK_COLOR)==> Running HCF ... $(NO_COLOR)"
	$(PWD)/bin/run.sh
