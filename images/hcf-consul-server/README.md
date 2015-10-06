# hcf-consul-server

A simple Docker image to setup a Consul server.

## Building

Build the `hcf-consul-base` image first.

Build this image:

    docker build -t hcf/consul-server .

## Usage

This boots Consul in server mode, with a default data directory of `/tmp/consul`.

Any arguments passed at the end of a `docker run` command will be passed to Consul.

## Examples

These examples show setting the Consul server to be available to all users in an unrestricted fashion, bound to all NICs - this is not a secure, production-level deployment strategy and is presented as an example only.

### Bootstrap with a single node (microcloud, not production quality)

    docker run -d -p 8300:8300 -p 8301:8301 -p 8302:8302 -p 8400:8400 -p 8500:8500 -p 8600:8600 -t hcf/consul-server -bootstrap -client=0.0.0.0

### Bootstrap with three nodes

    docker run -d -p 8300:8300 -p 8301:8301 -p 8302:8302 -p 8400:8400 -p 8500:8500 -p 8600:8600 -t hcf/consul-server -bootstrap-expect 3 -client=0.0.0.0

### Override the data directory

    docker run -d -p 8300:8300 -p 8301:8301 -p 8302:8302 -p 8400:8400 -p 8500:8500 -p 8600:8600 -e "DATA_DIR=/my_data_dir" -t hcf/consul-server -client=0.0.0.0

## Notes

This assumes you have multiple container hosts to run Consul on. A multi-node cluster running on the same container host is possible with advanced configuration to Consul, but not recommended and no examples will be provided.