.PHONY: clean build dist

include ../../version.mk

BRANCH:=$(shell git rev-parse --short HEAD)
BUILD:=$(shell whoami)-$(BRANCH)-$(shell date -u +%Y%m%d%H%M%S)
APP_VERSION=$(VERSION)-$(BUILD)

all: build dist

IMAGE_NAME=hcf/hcf-cfssl-build

clean:
	-docker rmi -f $(IMAGE_NAME)
	-docker rm -f $(IMAGE_NAME)
	-rm -rf dist
	-rm -rf _work

build:
	docker build -t $(IMAGE_NAME) .

dist:
	$(eval CONTAINER_ID="$(shell docker create $(IMAGE_NAME))")
	
	mkdir -p _work/hcf-cfssl
	mkdir -p dist

	docker cp $(CONTAINER_ID):/root/bin/. _work/hcf-cfssl

	cd _work ; tar czvf ../dist/hcf-cfssl-$(APP_VERSION).tar.gz hcf-cfssl/

	docker rm $(CONTAINER_ID)
