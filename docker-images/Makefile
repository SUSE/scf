.PHONY: hcf-consul-base hcf-consul-client hcf-consul-server hcf-cfssl

include ../version.mk

BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
COMMIT ?= $(shell git describe --tags --long | sed -r 's/[0-9.]+-([0-9]+)-(g[a-f0-9]+)/\1.\2/')
APP_VERSION ?= ${VERSION}+${COMMIT}.${BRANCH}
APP_VERSION_TAG ?= $(subst +,_,${APP_VERSION})


all: hcf-consul-base hcf-consul-client hcf-consul-server
build: all
tag: all
push: all

hcf-consul-base:
	make -C hcf-consul-base $(MAKECMDGOALS) BRANCH=$(BRANCH) BUILD=$(BUILD) APP_VERSION=$(APP_VERSION)

hcf-consul-client:
	make -C hcf-consul-client $(MAKECMDGOALS) BRANCH=$(BRANCH) BUILD=$(BUILD) APP_VERSION=$(APP_VERSION)

hcf-consul-server:
	make -C hcf-consul-server $(MAKECMDGOALS) BRANCH=$(BRANCH) BUILD=$(BUILD) APP_VERSION=$(APP_VERSION)
 
# hcf-cfssl:
# 	make -C hcf-cfssl $(MAKECMDGOALS) BRANCH=$(BRANCH) BUILD=$(BUILD) APP_VERSION=$(APP_VERSION)
