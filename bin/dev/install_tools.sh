#!/bin/bash
set -e

# Installs tools needed to build and run HCF
bin_dir="${bin_dir:-/home/vagrant/bin}"
tools_dir="${tools_dir:-/home/vagrant/tools}"
ubuntu_image="${ubuntu_image:-ubuntu:14.04}"
configgin_url="${configgin_url:-https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/hcf-ci-concourse/configgin-0.11.0%2B5-g86d9d64.develop-linux-x86_64.tgz}"
fissile_url="${fissile_url:-https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/hcf-ci-concourse/fissile-0.11.0%2B94.ge016820.HEAD-linux.amd64.tgz}"
gato_url="${gato_url:-https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/hcf-ci-concourse/gato-0.11.0%2B35.gd8840f5.HEAD-linux.amd64.tgz}"
cf_url="${cf_url:-https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.14.0&source=github-rel}"

mkdir -p $bin_dir
mkdir -p $tools_dir

echo "Fetching configgin ..."
wget -q "$configgin_url" -O $tools_dir/configgin.tgz
echo "Fetching cf CLI ..."
wget -q "$cf_url"        -O $tools_dir/cf.tgz
echo "Fetching fissile ..."
wget -q "$fissile_url"   -O - | tar xz -C $bin_dir fissile
echo "Fetching gato ..."
wget -q "$gato_url"      -O - | tar xz -C $bin_dir gato

echo "Unpacking cf CLI ..."
tar -xzf $tools_dir/cf.tgz -C $bin_dir

echo "Making binaries executable ..."
chmod +x $bin_dir/fissile
chmod +x $bin_dir/gato
chmod +x $bin_dir/cf

echo "Pulling base image ..."
docker pull $ubuntu_image
echo "Pulling ruby bosh image ..."
docker pull helioncf/hcf-pipeline-ruby-bosh

echo "Done."
