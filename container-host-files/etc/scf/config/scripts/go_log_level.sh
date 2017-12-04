#!/bin/bash

# The go components use their own set of log levels, compared to the
# standard set. They are a subset, contrary to the consul_agent. This
# script translates the standard set to the go set (best approx). The
# result is stored in the environment variable GO_LOG_LEVEL.

# This variable is used in the role manifest to specify various
# ".log_level"s for use by configgin.  The RM transformer knows that
# it is special.

export GO_LOG_LEVEL

case $LOG_LEVEL in
    debug2)
	GO_LOG_LEVEL=debug
	;;
    debug)
	GO_LOG_LEVEL=debug
	;;
    info)
	GO_LOG_LEVEL=info
	;;
    warn)
	GO_LOG_LEVEL=info
	;;
    warning)
	GO_LOG_LEVEL=info
	;;
    err)
	GO_LOG_LEVEL=error
	;;
    error)
	GO_LOG_LEVEL=error
	;;
    fatal)
	GO_LOG_LEVEL=fatal
	;;
    *)
	GO_LOG_LEVEL=info
	;;
esac
