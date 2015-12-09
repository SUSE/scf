#!/bin/bash
set -e

# Installs tools needed to build and run HCF
bin_dir="${bin_dir:-/home/vagrant/bin}"
tools_dir="${tools_dir:-/home/vagrant/tools}"
ubuntu_image="${ubuntu_image:-ubuntu:14.04}"
configgin_url="${configgin_url:-https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/configgin/configgin-1.0.1.16_develop%2Fconfiggin-1.0.1.16_develop-linux-x86_64.tgz}"
fissile_url="${fissile_url:-https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/fissile-artifacts/fissile-0.11.0.43_develop%2Fbuild%2Flinux-amd64%2Ffissile}"
gato_url="${gato_url:-https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/gato/gato-1.0.1.14-develop%2Fbuild%2Fgato}"
cf_url="${cf_url:-https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.14.0&source=github-rel}"

mkdir -p $bin_dir
mkdir -p $tools_dir

echo "Fetching configgin ..."
wget -q "$configgin_url" -O $tools_dir/configgin.tgz
echo "Fetching cf CLI ..."
wget -q "$cf_url" -O $tools_dir/cf.tgz
echo "Fetching fissile ..."
wget -q "$fissile_url"   -O $bin_dir/fissile
echo "Fetching gato ..."
wget -q "$gato_url"      -O $bin_dir/gato

echo "Unpacking cf CLI ..."
tar -xzf $tools_dir/cf.tgz -C $bin_dir

echo "Making binaries executable ..."
chmod +x $bin_dir/fissile
chmod +x $bin_dir/gato
chmod +x $bin_dir/cf

echo "Pulling base image ..."
docker pull $ubuntu_image

echo "Done."
