#!/bin/bash
# This script generates a new reproducible CA from the rep key and
# is added to auctioneer and bbs as a trusted cert for the rep client.
# This will allow a Windows Cell to issue its own certs with IP SANs
# NOTE: This cert is NOT trusted by the operating system or any other TLS client

# Dependency: certstrap Bosh Jobs form windows-runtime-release Bosh Release

mkdir -p /tmp/rep-ca
cd /tmp/rep-ca

/var/vcap/packages/certstrap/bin/certstrap init --common-name repCA --key /var/vcap/jobs/rep-certstrap/config/rep_ca.key --years 1000  --passphrase ""

repCAFile="./out/repCA.crt"

if [ -r /var/vcap/jobs/auctioneer/config/certs/rep/ca.crt ]; then
    cat $repCAFile >> /var/vcap/jobs/auctioneer/config/certs/rep/ca.crt
fi

if [ -r /var/vcap/jobs/bbs/config/certs/rep/ca.crt ]; then
    cat $repCAFile >> /var/vcap/jobs/bbs/config/certs/rep/ca.crt
fi

rm -rf /tmp/rep-ca 
