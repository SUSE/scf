This directory contains the settings used for the vagrant boxes, which are also
the defaults for HCP/AWS.  `rm-transformer` takes these and applies _additional_
settings on top from the other directories.

**NOTE**: The files here, for use with vagrant/docker, only accept `key=value`
pairs.  `rm-transformer` can additionally handle comments and `unset key`.
