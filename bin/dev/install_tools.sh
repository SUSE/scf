#!/bin/bash
set -e

configgin_url="${configgin_url:-https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/configgin/configgin-1.0.1.16_develop%2Fconfiggin-1.0.1.16_develop-linux-x86_64.tgz}"
fissile_url="${fissile_url:-https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/fissile-artifacts/fissile-1.0.1.28_develop%2Fbuild%2Flinux-amd64%2Ffissile}"
gato_url="${gato_url:-https://region-b.geo-1.objects.hpcloudsvc.com/v1/54026737306152/gato/gato-1.0.1.14-develop%2Fbuild%2Fgato}"
bin_dir="${bin_dir:-/home/vagrant/bin}"
tools_dir="${tools_dir:-/home/vagrant/tools}"

mkdir -p $bin_dir
mkdir -p $tools_dir

wget -q "$configgin_url" -O $tools_dir/configgin.tgz
wget -q "$fissile_url"   -O $bin_dir/fissile
wget -q "$gato_url"      -O $bin_dir/gato

chown vagrant $bin_dir
chown vagrant $bin_dir/*
chown vagrant $tools_dir
chown vagrant $tools_dir/*

chmod +x $bin_dir/fissile
chmod +x $bin_dir/gato

docker pull ubuntu:14.04
