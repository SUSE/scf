#!/bin/sh 

set -e

case $# in
  0) args=apply ;;
  *) args="$@" ;;
esac

problems=0
for var in KEY_FILE OS_USERNAME OS_PASSWORD RUNTIME_USERNAME ; do
  eval val=$(echo \$$var)
  if [ -z "$val" ] ; then
    echo "$var is unset"
    problems=1
  fi
done
case $problems in
  1) exit 1 ;;
esac

if [ ! -f "${KEY_FILE}" ] ; then
  echo "File ${KEY_FILE} not found"
  exit 2
fi

TF_VAR_key_pair=$(basename $KEY_FILE .pem) \
    TF_VAR_key_file=$KEY_FILE \
    TF_VAR_os_user=$OS_USERNAME \
    TF_VAR_os_password=$OS_PASSWORD \
    TF_VAR_runtime_username=$RUNTIME_USERNAME \
    terraform "$args"
