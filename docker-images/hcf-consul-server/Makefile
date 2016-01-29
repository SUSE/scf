.PHONY: build tag push

include ../../version.mk

BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
COMMIT ?= $(shell git describe --tags --long | sed -r 's/[0-9.]+-([0-9]+)-(g[a-f0-9]+)/\1.\2/')
APP_VERSION ?= ${VERSION}+${COMMIT}.${BRANCH}
APP_VERSION_TAG ?= $(subst +,_,${APP_VERSION})

all: build tag push

IMAGE_NAME=helioncf/hcf-consul-server

build:
	docker build -t $(IMAGE_NAME) .

tag:
	docker tag -f $(IMAGE_NAME) $(IMAGE_NAME):${APP_VERSION_TAG}
	docker tag -f $(IMAGE_NAME) $(IMAGE_NAME):latest-$(BRANCH)

push:
	docker push $(IMAGE_NAME):${APP_VERSION_TAG}
	docker push $(IMAGE_NAME):latest-$(BRANCH)	
