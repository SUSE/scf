#!/bin/bash
set -o errexit -o nounset

# prevent cd from printing the directory it changes to. This breaks
# cd/pwd constructions (See **).
unset CDPATH

# Get version information
. "$(dirname "$0")/versions.sh"

# Tool locations
s3="https://cf-opensusefs2.s3.amazonaws.com/fissile"

# Tool versions
thefissile="fissile-$(echo "${FISSILE_VERSION}" | sed -e 's/+/%2B/')"

# Installs tools needed to build and run HCF
bin_dir="${bin_dir:-output/bin}"
tools_dir="${tools_dir:-output/tools}"
ubuntu_image="${ubuntu_image:-ubuntu:${UBUNTU_VERSION}}"
fissile_url="${fissile_url:-${s3}/${thefissile}.linux-amd64.tgz}"
cf_url="${cf_url:-https://cli.run.pivotal.io/stable?release=linux64-binary&version=${CFCLI_VERSION}&source=github-rel}"
stampy_url="${stampy_url:-https://github.com/SUSE/stampy/releases/download/${STAMPY_MAJOR}/stampy-${STAMPY_VERSION}.linux-amd64.tgz}"
kubectl_url="${kubectl_url:-https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl}"
k_url="${k_url:-https://github.com/aarondl/kctl/releases/download/v${K_VERSION}/kctl-linux-amd64}"
kk_url="${kk_url:-https://gist.githubusercontent.com/jandubois/40a5b3756cf4bcbed940e6156272c0af/raw/${KK_VERSION}/kk}"
helm_url="${helm_url:-https://kubernetes-helm.storage.googleapis.com/helm-v${HELM_VERSION}-linux-amd64.tar.gz}"

mkdir -p "${bin_dir}"
mkdir -p "${tools_dir}"

# (**)
bin_dir="$(cd "${bin_dir}" && pwd)"

echo "Fetching cf CLI $cf_url ..."
wget -q "$cf_url"        -O "${tools_dir}/cf.tgz"
echo "Fetching fissile $fissile_url ..."
wget -q "$fissile_url"   -O - | tar xz --to-stdout fissile > "${FISSILE_BINARY}"
echo "Installed: $("${FISSILE_BINARY}" version)"

echo "Fetching stampy $stampy_url ..."
wget -q "$stampy_url"   -O - | tar xz -C "${bin_dir}" stampy

echo "Unpacking cf CLI ..."
tar -xzf "${tools_dir}/cf.tgz" -C "${bin_dir}"

echo "Fetching kubectl ${kubectl_url} ..."
wget -q "${kubectl_url}" -O "${bin_dir}/kubectl"
wget -q "${k_url}" -O "${bin_dir}/k"
wget -q "${kk_url}" -O "${bin_dir}/kk"

echo "Fetching helm from ${helm_url} ..."
wget -q "${helm_url}" -O - | tar xz -C "${bin_dir}" --strip-components=1 linux-amd64/helm

echo "Making binaries executable ..."
chmod a+x "${FISSILE_BINARY}"
chmod a+x "${bin_dir}/stampy"
chmod a+x "${bin_dir}/cf"
chmod a+x "${bin_dir}/kubectl"
chmod a+x "${bin_dir}/k"
chmod a+x "${bin_dir}/kk"
chmod a+x "${bin_dir}/helm"

echo "Installing certstrap ..."
# We run chown in docker to avoid requiring sudo
docker run --rm -v "${bin_dir}":/out:rw "golang:${GOLANG_VERSION}" /usr/bin/env GOBIN=/out go get github.com/square/certstrap
if [[ $(stat -c '%u' "${bin_dir}/certstrap") -eq 0 ]]; then
  docker run --rm -v "${bin_dir}":/out:rw "golang:${GOLANG_VERSION}" /bin/chown "$(id -u):$(id -g)" /out/certstrap
fi

echo "Pulling ruby bosh image ..."
docker pull splatform/bosh-cli

# Note that we might not have a k8s available; do this only if we're in vagrant
if systemctl is-active kube-apiserver.service ; then
  echo "Installing tiller for helm ..."
  helm init
else
  echo "Skipping tiller installation for helm; no local kube found"
fi

echo "Installing helm-certgen ..."
helm_certgen_dir="$(mktemp -d)"
trap "rm -rf '${helm_certgen_dir}'" EXIT
git clone --branch "${HELM_CERTGEN_VERSION}" --depth 1 https://github.com/SUSE/helm-certgen.git "${helm_certgen_dir}"
docker run --rm -v "${bin_dir}":/out:rw -v "${helm_certgen_dir}:/go/src/github.com/SUSE/helm-certgen:ro" "golang:${GOLANG_VERSION}" /usr/bin/env GOBIN=/out go get github.com/SUSE/helm-certgen
if [[ $(stat -c '%u' "${bin_dir}/helm-certgen") -eq 0 ]]; then
  docker run --rm -v "${bin_dir}":/out:rw "golang:${GOLANG_VERSION}" /bin/chown "$(id -u):$(id -g)" /out/helm-certgen
fi
mkdir -p "${HOME}/.helm/plugins" # Necessary if we didn't run `helm init`
rm -rf "${HOME}/.helm/plugins/certgen"
mv --no-target-directory "${helm_certgen_dir}/plugin" "${HOME}/.helm/plugins/certgen"
rm -rf "${helm_certgen_dir}"

echo "Done."
