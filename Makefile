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

REGISTRY_HOST?=15.126.242.125:5000

COMPONENTS=nats 

include version.mk

all: publish_images

.PHONY: all clean setup tools fetch_fissle

clean:
	@echo "$(OK_COLOR)==> Cleaning$(NO_COLOR)"
	rm -rf $(WORK_DIR) $(TARGET_DIR)
	-docker rm --force $(shell docker ps -a | grep fissile | cut -f1 -d' ')

setup:
	@echo "$(OK_COLOR)==> Setup$(NO_COLOR)"
	mkdir -p $(TARGET_DIR)
	mkdir -p $(WORK_DIR)
	docker pull $(UBUNTU_IMAGE)

fetch_fissle: setup
	@echo "$(OK_COLOR)==> Looking up latest fissile build$(NO_COLOR)"
	# Find the latest artifact, excluding the babysitter builds
	# This looks inside the swift container, filtering by your OS type, sorts in ascending order and takes the last entry	
	# If we were to write a "latest" link, this would be easier.
	$(eval LATEST_FISSILE_BUILD="$(shell swift list -l fissile-artifacts | grep -v babysitter | grep $(OS_TYPE) | cut -c 14-33,34- | sort | tail -1)")

	swift download --output $(WORK_DIR)/fissile fissile-artifacts $(shell echo $(LATEST_FISSILE_BUILD) | cut -c 21-)
	chmod +x $(WORK_DIR)/fissile

fetch_configgin: setup
	@echo "$(OK_COLOR)==> Looking up latest configgin build$(NO_COLOR)"

	$(eval LATEST_CONFIGGIN_BUILD="$(shell swift list -l configgin | grep -v babysitter | grep linux-x86_64.tgz | cut -c 14-33,34- | sort | tail -1)")
	swift download --output $(WORK_DIR)/configgin.tar.gz configgin $(shell echo $(LATEST_CONFIGGIN_BUILD) | cut -c 21-)

tools: fetch_fissle fetch_configgin
	$(WORK_DIR)/fissile

images: setup compile_release
	@echo "$(OK_COLOR)==> Build all Docker images$(NO_COLOR)"
	make -C images all

fetch_cf_release: fetch_fissle
	@echo "$(OK_COLOR)==> Fetching cf-release $(CF_RELEASE)$(NO_COLOR)"

	curl -L "$(CF_RELEASE_LOCATION)" -o $(WORK_DIR)/cf-release.tar.gz 
	mkdir -p $(RELEASE_DIR) && cd $(RELEASE_DIR) && tar zxf ../cf-release.tar.gz

compile_base: fetch_cf_release fetch_configgin
	@echo "$(OK_COLOR)==> Compiling base image for cf-release$(NO_COLOR)"
	-docker rm fissile-cf-$(CF_RELEASE)-cbase
	-docker rmi fissile:cf-$(CF_RELEASE)-cbase

	_work/fissile compilation build-base -r $(RELEASE_DIR) -b $(UBUNTU_IMAGE)

compile_release: compile_base
	@echo "$(OK_COLOR)==> Compiling cf-release$(NO_COLOR)"
	_work/fissile compilation start -r $(RELEASE_DIR) -t $(WORK_DIR)/compile_target -b $(UBUNTU_IMAGE)

base_image: compile_release
	_work/fissile images create-base -t $(WORK_DIR)/base_image -c $(WORK_DIR)/configgin.tar.gz -r $(RELEASE_DIR) -b $(UBUNTU_IMAGE)

compile_images: base_image
	_work/fissile images create-roles -t $(WORK_DIR)/images -r $(RELEASE_DIR) -m $(PWD)/config-opinions/cf-v$(CF_RELEASE)/role-manifest.yml -c $(WORK_DIR)/compile_target -v $(VERSION)

publish_images: compile_images
	@for component in $(COMPONENTS); do \
		docker tag fissile:cf-$(CF_RELEASE)-$$component $(REGISTRY_HOST)/hcf:cf-$(CF_RELEASE)-$$component; \
		docker push $(REGISTRY_HOST)/hcf:cf-$(CF_RELEASE)-$$component; \
	done