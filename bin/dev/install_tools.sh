#!/bin/bash
set -e

# Installs tools needed to build and run HCF
bin_dir="${bin_dir:-/home/vagrant/bin}"
tools_dir="${tools_dir:-/home/vagrant/tools}"
fissile_url="${fissile_url:-https://concourse-hpe.s3.amazonaws.com/fissile-4.0.0%2B132.g8fa6780.linux-amd64.tgz}"
cf_url="${cf_url:-https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.21.1&source=github-rel}"
stampy_url="${stampy_url:-https://concourse-hpe.s3.amazonaws.com/stampy-0.0.0%2B7.g4d305fa.master-linux.amd64.tgz}"
kubectl_url="${kubectl_url:-https://storage.googleapis.com/kubernetes-release/release/v1.5.4/bin/linux/amd64/kubectl}"
k_url="${k_url:-https://github.com/aarondl/kctl/releases/download/v0.0.1/kctl-linux-amd64}"


mkdir -p $bin_dir
mkdir -p $tools_dir

echo "Fetching cf CLI ..."
wget -q "$cf_url"        -O $tools_dir/cf.tgz
echo "Fetching fissile ..."
wget -q "$fissile_url"   -O - | tar xz -C $bin_dir fissile

echo "Fetching stampy ..."
wget -q "$stampy_url"   -O - | tar xz -C $bin_dir stampy

echo "Unpacking cf CLI ..."
tar -xzf $tools_dir/cf.tgz -C $bin_dir

echo "Fetching kubectl ..."
wget -q "${kubectl_url}" -O "${bin_dir}/kubectl"
wget -q "${k_url}" -O "${bin_dir}/k"

echo "Making binaries executable ..."
chmod +x $bin_dir/fissile
chmod +x $bin_dir/stampy
chmod +x $bin_dir/cf
chmod +x "${bin_dir}/kubectl"
chmod +x "${bin_dir}/k"

echo "Pulling ruby bosh image ..."
docker pull helioncf/hcf-pipeline-ruby-bosh

echo "Done."
