.PHONY: build tag push

include ../../version.mk

BRANCH:=$(shell git rev-parse --short HEAD)
BUILD:=$(shell whoami)-$(BRANCH)-$(shell date -u +%Y%m%d%H%M%S)
APP_VERSION=$(VERSION)-$(BUILD)

all: build tag push

IMAGE_NAME=helioncf/hcf-consul-client

build:
	docker build -t $(IMAGE_NAME) .

tag:
	docker tag -f $(IMAGE_NAME) $(IMAGE_NAME):$(APP_VERSION)
	docker tag -f $(IMAGE_NAME) $(IMAGE_NAME):latest-$(BRANCH)

push:
	docker push $(IMAGE_NAME):$(APP_VERSION)
	docker push $(IMAGE_NAME):latest-$(BRANCH)	
