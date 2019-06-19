#!/bin/bash

# The log levels we expect are different from the values expected by Log4j.
# We map them to sensible values here

case "${LOG_LEVEL,,}" in
    debug2) LOG_LEVEL_LOG4J=ALL   ;;
    debug1) LOG_LEVEL_LOG4J=TRACE ;;
    debug)  LOG_LEVEL_LOG4J=DEBUG ;;
    info)   LOG_LEVEL_LOG4J=INFO  ;;
    warn)   LOG_LEVEL_LOG4J=WARN  ;;
    error)  LOG_LEVEL_LOG4J=ERROR ;;
    fatal)  LOG_LEVEL_LOG4J=ERROR ;;
    off)    LOG_LEVEL_LOG4J=OFF   ;;
    *)      LOG_LEVEL_LOG4J=ERROR ;; # Default log level
esac

export LOG_LEVEL_LOG4J
