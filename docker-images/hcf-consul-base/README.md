# hcf-consul-base

A base Dockerfile for building Consul-based Docker containers.

## Building

    docker build -t hcf:consul-base .

## Using

This is intended to be the `FROM` value in a child Dockerfile.

Example:

    FROM hcf:consul-base
    RUN ...

See `hcf-consul-server` for a more concrete example.