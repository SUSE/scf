#!/bin/bash
set -o errexit -o nounset

cd /var/vcap/packages
BASE_NAME=$(ls -1d a*)
case ${BASE_NAME} in
  autoscaler_*) ;;
  *) echo Encountered unexpected directory name of "${BASE_NAME}"; exit 1 ;;
esac
SHORT_NAME=${BASE_NAME:11} # drop leading "autoscaler_"
CLASSES_PATH="/var/vcap/packages/${BASE_NAME}/${SHORT_NAME}/WEB-INF/classes"

cd "${CLASSES_PATH}"
if [ ! -f config.properties.orig ] ; then
  cp config.properties config.properties.orig
fi

if [ "${SHORT_NAME}" == "servicebroker" ] ; then
  if [ ! -f catalog.json.orig ] ; then
    cp catalog.json catalog.json.orig
  fi

SERVICE_BROKER_CATALOG=$(cat <<EOF
  ,
    "${CLASSES_PATH}/catalog.json.orig": "${CLASSES_PATH}/catalog.json"
EOF
)

fi

cat > "/opt/hcf/${BASE_NAME}_job_config.json" <<EOF
{
  "${BASE_NAME}": {
    "base": "/var/vcap/jobs-src/${BASE_NAME}/config_spec.json",
    "files": {
      "${CLASSES_PATH}/config.properties.orig": "${CLASSES_PATH}/config.properties"
      ${SERVICE_BROKER_CATALOG:-}
    }
  }
}
EOF

/opt/hcf/configgin/configgin \
  --jobs "/opt/hcf/${BASE_NAME}_job_config.json" \
  --env2conf /opt/hcf/env2conf.yml
