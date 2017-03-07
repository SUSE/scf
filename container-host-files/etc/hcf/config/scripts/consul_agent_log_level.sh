#!/bin/bash

# The consul agent uses its own set of log levels, compared to the
# standard set. This script translates the standard set to the consul
# set (best approx). The result is stored in the environment variable
# CONSUL_LOG_LEVEL.

# This variable is used in the role manifest to specify
# "consul.agent.log_level" for use by configgin.  The RM transformer
# knows that it is special.

export CONSUL_LOG_LEVEL

case $LOG_LEVEL in
    debug2)
	CONSUL_LOG_LEVEL=trace
	;;
    debug)
	CONSUL_LOG_LEVEL=debug
	;;
    info)
	CONSUL_LOG_LEVEL=info
	;;
    warn)
	CONSUL_LOG_LEVEL=warn
	;;
    warning)
	CONSUL_LOG_LEVEL=warn
	;;
    err)
	CONSUL_LOG_LEVEL=err
	;;
    error)
	CONSUL_LOG_LEVEL=err
	;;
    fatal)
	CONSUL_LOG_LEVEL=err
	;;
    *)
	CONSUL_LOG_LEVEL=info
	;;
esac
