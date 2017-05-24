#!/bin/bash
set -o errexit -o nounset

# Tool locations
vanbuckets="http://concourse.van:9000/minio"
minio="https://minio.from-the.cloud:9000/fissile"

# Tool versions
thefissile="$(echo "fissile-5.0.0+14.g22080c2" | sed -e 's/+/%2B/')"

# Installs tools needed to build and run HCF
bin_dir="${bin_dir:-output/bin}"
tools_dir="${tools_dir:-output/tools}"
ubuntu_image="${ubuntu_image:-ubuntu:14.04}"
fissile_url="${fissile_url:-${minio}/${thefissile}.linux-amd64.tgz}"
cf_url="${cf_url:-https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.21.1&source=github-rel}"
stampy_url="${stampy_url:-https://concourse-hpe.s3.amazonaws.com/stampy-0.0.0%2B7.g4d305fa.master-linux.amd64.tgz}"
kubectl_url="${kubectl_url:-https://storage.googleapis.com/kubernetes-release/release/v1.5.4/bin/linux/amd64/kubectl}"
k_url="${k_url:-https://github.com/aarondl/kctl/releases/download/v0.0.1/kctl-linux-amd64}"

mkdir -p "${bin_dir}"
mkdir -p "${tools_dir}"

echo "Fetching cf CLI ..."
wget -q "$cf_url"        -O "${tools_dir}/cf.tgz"
echo "Fetching fissile ..."
wget -q "$fissile_url"   -O - | tar xz --to-stdout fissile > "${FISSILE_BINARY}"

echo "Fetching stampy ..."
wget -q "$stampy_url"   -O - | tar xz -C "${bin_dir}" stampy

echo "Unpacking cf CLI ..."
tar -xzf "${tools_dir}/cf.tgz" -C "${bin_dir}"

echo "Fetching kubectl ..."
wget -q "${kubectl_url}" -O "${bin_dir}/kubectl"
wget -q "${k_url}" -O "${bin_dir}/k"

echo "Making binaries executable ..."
chmod a+x "${FISSILE_BINARY}"
chmod a+x "${bin_dir}/stampy"
chmod a+x "${bin_dir}/cf"
chmod a+x "${bin_dir}/kubectl"
chmod a+x "${bin_dir}/k"

echo "Pulling ruby bosh image ..."
docker pull splatform/bosh-cli

echo "Done."
