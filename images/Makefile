export REGISTRY?=15.126.242.125:5000

.PHONY: hcf-consul-base hcf-consul-client hcf-consul-server

all: hcf-consul-base hcf-consul-client hcf-consul-server

hcf-consul-base:
	make -C hcf-consul-base

hcf-consul-client:
	make -C hcf-consul-client

hcf-consul-server:
	make -C hcf-consul-server
