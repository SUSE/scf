#!/bin/bash

# The credhub component uses its own set of log levels, compared to
# the standard set. This script translates the standard set to the
# credhub set (best approx). The result is stored in the environment
# variable CREDHUB_LOG_LEVEL.

# This variable is used in the role manifest to specify various
# ".log_level"s for use by configgin.

export CREDHUB_LOG_LEVEL

case $LOG_LEVEL in
    debug2)
	CREDHUB_LOG_LEVEL=debug
	;;
    debug)
	CREDHUB_LOG_LEVEL=debug
	;;
    info)
	CREDHUB_LOG_LEVEL=info
	;;
    warn)
	CREDHUB_LOG_LEVEL=warn
	;;
    warning)
	CREDHUB_LOG_LEVEL=warn
	;;
    err)
	CREDHUB_LOG_LEVEL=error
	;;
    error)
	CREDHUB_LOG_LEVEL=error
	;;
    fatal)
	CREDHUB_LOG_LEVEL=error
	;;
    *)
	CREDHUB_LOG_LEVEL=info
	;;
esac
