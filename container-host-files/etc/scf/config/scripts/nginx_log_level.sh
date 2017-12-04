#!/bin/bash

# The nginx components use their own set of log levels, compared to
# the standard set. This script translates the standard set to the
# nginx set (best approx). The result is stored in the environment
# variable NGINX_LOG_LEVEL.
#
# Levels: debug, info, notice, warn, error, crit, alert, emerg

# This variable is used in the role manifest to specify various
# ".log_level"s for use by configgin.  The RM transformer knows that
# it is special.

export NGINX_LOG_LEVEL

case $LOG_LEVEL in
    debug2)
	NGINX_LOG_LEVEL=debug
	;;
    debug)
	NGINX_LOG_LEVEL=debug
	;;
    info)
	NGINX_LOG_LEVEL=notice
	;;
    warn)
	NGINX_LOG_LEVEL=warn
	;;
    warning)
	NGINX_LOG_LEVEL=warn
	;;
    err)
	NGINX_LOG_LEVEL=error
	;;
    error)
	NGINX_LOG_LEVEL=error
	;;
    fatal)
	NGINX_LOG_LEVEL=emerg
	;;
    *)
	NGINX_LOG_LEVEL=info
	;;
esac
