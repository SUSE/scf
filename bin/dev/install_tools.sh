#!/bin/bash
set -e

configgin_url="${configgin_url:-https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/configgin/configgin-1.0.1.16_develop%2Fconfiggin-1.0.1.16_develop-linux-x86_64.tgz}"
fissile_url="${fissile_url:-https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/fissile-artifacts/fissile-1.0.1.26_develop%2Fbuild%2Flinux-amd64%2Ffissile}"
bin_dir="${bin_dir:-/home/vagrant/bin}"
tools_dir="${tools_dir:-/home/vagrant/tools}"

mkdir $bin_dir
mkdir $tools_dir

wget $configgin_url -O $tools_dir/configgin.tgz 2>/dev/null
wget $fissile_url -O $bin_dir/fissile 2>/dev/null

chown vagrant $bin_dir
chown vagrant $tools_dir

chmod +x $bin_dir/fissile

docker pull ubuntu:14.04
