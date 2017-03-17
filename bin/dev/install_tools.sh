#!/bin/bash
set -e

# Installs tools needed to build and run HCF
bin_dir="${bin_dir:-/home/vagrant/bin}"
tools_dir="${tools_dir:-/home/vagrant/tools}"
fissile_url="${fissile_url:-https://s3-us-west-2.amazonaws.com/concourse-hpe/checks/fissile-4.0.0%2B128.g21e60d5.linux-amd64.tgz}"
cf_url="${cf_url:-https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.21.1&source=github-rel}"
stampy_url="${stampy_url:-https://concourse-hpe.s3.amazonaws.com/stampy-0.0.0%2B7.g4d305fa.master-linux.amd64.tgz}"


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

echo "Making binaries executable ..."
chmod +x $bin_dir/fissile
chmod +x $bin_dir/stampy
chmod +x $bin_dir/cf

echo "Pulling ruby bosh image ..."
docker pull helioncf/hcf-pipeline-ruby-bosh

echo "Done."
