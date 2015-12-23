#!/bin/bash
# © Copyright 2015 Hewlett Packard Enterprise Development LP

set -e

# generate the root CA
mkdir -p certs crl newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial

echo "Generate root CA key"

openssl genrsa -aes256 -passout pass:foobar \
  -out private/ca.key.pem 4096
chmod 400 private/ca.key.pem

echo "Generate root CA cert"

openssl req -config root_openssl.cnf \
  -passin pass:foobar \
  -passout pass:foobar \
  -key private/ca.key.pem \
  -new -x509 -days 7300 -sha256 -extensions v3_ca \
  -subj '/C=US/ST=Washington/L=Seattle/O=Hewlett Packard Enterprise/OU=Helion Cloud Foundry/CN=Root Self-Signing Authority/' \
  -out certs/ca.cert.pem
chmod 444 certs/ca.cert.pem

echo "Root CA created:"
openssl x509 -noout -text -in certs/ca.cert.pem  
