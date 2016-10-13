#!/bin/bash
set -o errexit -o nounset

# Usage: run_configin <job> <input>  <output>
#                     name  template destination
function run_configgin()
{
        job_name="$1"
        template_file="$2"
        output_file="$3"
        /opt/hcf/configgin/configgin \
        --input-erb ${template_file} \
        --output ${output_file} \
        --base /var/vcap/jobs-src/${job_name}/config_spec.json \
        --env2conf /opt/hcf/env2conf.yml
}

cd /var/vcap/packages
BASE_NAME=$(ls -1d a*)
case ${BASE_NAME} in
  autoscaler_*) ;;
  *) echo Encountered unexpected directory name of ${BASE_NAME}; exit 1 ;;
esac
SHORT_NAME=${BASE_NAME:11} # drop leading "autoscaler_"

cd ${BASE_NAME}/${SHORT_NAME}/WEB-INF/classes
if [ ! -f config.properties.orig ] ; then
  cp config.properties config.properties.orig
fi
run_configgin ${BASE_NAME} config.properties.orig config.properties

if [ "${SHORT_NAME}" == "servicebroker" ] ; then
  if [ ! -f catalog.json.orig ] ; then
    cp catalog.json catalog.json.orig
  fi

  run_configgin ${BASE_NAME} catalog.json.orig catalog.json
fi
