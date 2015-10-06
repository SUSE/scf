.PHONY: build tag push

all: build tag push

IMAGE_NAME=hcf/consul-base

build:
	docker build -t $(IMAGE_NAME) .

tag:
	docker tag -f $(IMAGE_NAME) $(REGISTRY)/$(IMAGE_NAME)

push:
	docker push $(REGISTRY)/$(IMAGE_NAME)
