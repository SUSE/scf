# hcf-consul-client

A Dockerfile to interact with Consul from a client level.

## Building

    docker build -t hcf/consul-client .

## Use cases

### Generating an key for encrypted Consul traffic

    docker run -t hcf/consul-client keygen

### Joining nodes to a cluster

    docker run -t hcf/consul-client join <server 1> <server 2> <server 3> <server ...>