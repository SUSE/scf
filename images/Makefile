.PHONY: hcf-consul-base hcf-consul-client hcf-consul-server hcf-cfssl

include ../version.mk

BRANCH:=$(shell git rev-parse --short HEAD)
BUILD:=$(shell whoami)-$(BRANCH)-$(shell date -u +%Y%m%d%H%M%S)
APP_VERSION=$(VERSION)-$(BUILD)

all: hcf-consul-base hcf-consul-client hcf-consul-server hcf-cfssl

hcf-consul-base:
	make -C hcf-consul-base BRANCH=$(BRANCH) BUILD=$(BUILD) APP_VERSION=$(APP_VERSION)

hcf-consul-client:
	make -C hcf-consul-client BRANCH=$(BRANCH) BUILD=$(BUILD) APP_VERSION=$(APP_VERSION)

hcf-consul-server:
	make -C hcf-consul-server BRANCH=$(BRANCH) BUILD=$(BUILD) APP_VERSION=$(APP_VERSION)

hcf-cfssl:
	make -C hcf-cfssl BRANCH=$(BRANCH) BUILD=$(BUILD) APP_VERSION=$(APP_VERSION)
