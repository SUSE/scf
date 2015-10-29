export REGISTRY:=15.126.242.125:5000

.PHONY: hcf-consul-base hcf-consul-client hcf-consul-server

include ../version.mk

BRANCH:=$(shell git rev-parse --short HEAD)
BUILD:=$(shell whoami)-$(BRANCH)-$(shell date -u +%Y%m%d%H%M%S)
APP_VERSION=$(VERSION)-$(BUILD)

all: hcf-consul-base hcf-consul-client hcf-consul-server

hcf-consul-base:
	make -C hcf-consul-base BRANCH=$(BRANCH) BUILD=$(BUILD) APP_VERSION=$(APP_VERSION)

hcf-consul-client:
	make -C hcf-consul-client BRANCH=$(BRANCH) BUILD=$(BUILD) APP_VERSION=$(APP_VERSION)

hcf-consul-server:
	make -C hcf-consul-server BRANCH=$(BRANCH) BUILD=$(BUILD) APP_VERSION=$(APP_VERSION)
