#!/bin/sh 

set -ex

TF_VAR_key_file=${KEY_FILE:-ericp01.pem} \
    TF_VAR_cloud_username=$OS_HPCLOUD_USERNAME \
    TF_VAR_cloud_password=$OS_HPCLOUD_PASSWORD \
    TF_VAR_runtime_username=$RUNTIME_USERNAME \
    terraform apply
