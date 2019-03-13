#!/bin/bash

# This script is used to open a PR against this repository:
# https://github.com/suse/kubernetes-charts-suse-com
# It will fetch the bundle specified by CAP_BUNDLE and will update the helm
# charts in the above repo.

set -e

if [ -z "$GITHUB_USER"  ]; then
  echo "GITHUB_USER environment variable not set"
  exit 1
fi

if [ -z "$GITHUB_PASSWORD" ] && [ -z "${GITHUB_TOKEN}" ] ; then
  echo "GITHUB_PASSWORD environment variable not set"
  exit 1
fi

if [[ -z "${CAP_BUNDLE}" ]]; then
  echo "CAP_BUNDLE not set"
  exit 1
fi

TMP_WORKDIR=$(mktemp -d -p $PWD)
trap "rm -rf ${TMP_WORKDIR}" EXIT

pushd $TMP_WORKDIR

# Get the "hub" cli
# https://hub.github.com/hub.1.html
curl -L https://github.com/github/hub/releases/download/v2.3.0-pre10/hub-linux-amd64-2.3.0-pre10.tgz | tar xvz --wildcards --strip-components=2 '*/bin/hub'
HUB="${PWD}/hub"
chmod +x $HUB

# Clone the kubernetes-charts-suse-com github repo
$HUB clone git@github.com:SUSE/kubernetes-charts-suse-com.git

mkdir bundle
wget -O bundle.zip "${CAP_BUNDLE}"
unzip -d bundle/ bundle.zip
bundle=$(basename "$CAP_BUNDLE" .zip)
bundle_readable=$(printf '%b' "${bundle//%/\\x}")
product=`echo $bundle_readable | cut -d+ -f1`
pr_title="Release $product"
pr_description="Publish Helm charts for release $product created from $bundle_readable.zip built in Jenkins run $SOURCE_BUILD."

cd kubernetes-charts-suse-com
# Remove old charts
rm -rf stable/cf
rm -rf stable/uaa
# Place the new ones
cp -r ../bundle/helm/cf stable/
cp -r ../bundle/helm/uaa stable/

sed -i 's@^\(\s\+\)hostname:\s\+".*"$@\1hostname: "registry.suse.com"@' stable/cf/values.yaml
sed -i 's@^\(\s\+\)hostname:\s\+".*"$@\1hostname: "registry.suse.com"@' stable/uaa/values.yaml

sed -i 's@^\(\s\+\)organization:\s\+".*"$@\1organization: "cap"@' stable/cf/values.yaml
sed -i 's@^\(\s\+\)organization:\s\+".*"$@\1organization: "cap"@' stable/uaa/values.yaml

$HUB config user.email "cf-ci-bot@suse.de"
$HUB config user.name "${GITHUB_USER}"
$HUB checkout -b $bundle
$HUB -c core.fileMode=false add .
$HUB commit -m "Submitting "$bundle
$HUB push origin $bundle

# Open a Pull Request, head: current branch, base: master
$HUB pull-request -m "$(printf "$pr_title\n\n$pr_description")" -b master
