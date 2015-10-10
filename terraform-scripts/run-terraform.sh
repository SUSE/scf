#!/bin/sh 

set -ex

case $# in
  0) args=apply ;;
  *) args="$@" ;;
esac

TF_VAR_key_file=${KEY_FILE:-ericp01.pem} \
    TF_VAR_os_user=$OS_USERNAME \
    TF_VAR_os_password=$OS_PASSWORD \
    TF_VAR_runtime_username=$RUNTIME_USERNAME \
    terraform $args
