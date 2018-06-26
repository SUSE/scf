#!/bin/sh

set -o errexit
set -o xtrace

wget -O /tmp/txtplate https://github.com/SUSE/txtplate/releases/download/v0.0.4/txtplate-linux-amd64
chmod +x /tmp/txtplate

get_helm_images() {
    DIR=$1
    VALUES=$2

    for i in $(find "${DIR}" -type f -name Chart.yaml); do
        DIR=$(dirname "${i}")
        grep --fixed-string --no-filename 'image:' ${DIR}/templates/* \
            | sed 's@\.Values@@g' \
            | /tmp/txtplate "${DIR}/values.yaml" "${VALUES}" \
            | grep --extended --only-matching '([^"/[:space:]]+/)?[^"/[:space:]]+/[^:[:space:]]+:[a-zA-Z0-9\._-]+' \
            | xargs --no-run-if-empty -n1 docker pull
    done
}

cat > /tmp/values.json <<EOF
{
    "kube": {
        "registry": { "hostname": "docker.io" },
        "organization": "splatform"
    }
}
EOF

get_helm_images /home/scf/helm /tmp/values.json
get_helm_images /home/scf/console /tmp/values.json
get_helm_images /home/scf/console/charts/mariadb /tmp/values.json
