#!/bin/bash
set -e

# generate the intermediate CA
mkdir -p intermediate
mkdir -p intermediate/certs
mkdir -p intermediate/crl
mkdir -p intermediate/newcerts
mkdir -p intermediate/private
mkdir -p intermediate/csr

chmod 700 intermediate/private
touch intermediate/index.txt
echo 1000 > intermediate/serial
echo 1000 > intermediate/crlnumber

echo "Generate intermediate CA key"

openssl genrsa -aes256 -passout pass:foobar \
  -out intermediate/private/intermediate.key.pem 4096  
chmod 400 intermediate/private/intermediate.key.pem

echo "Generate intermediate CA CSR"

openssl req -config intermediate_openssl.cnf -new -sha256 \
  -key intermediate/private/intermediate.key.pem \
  -out intermediate/csr/intermediate.csr.pem \
  -subj '/C=US/ST=Washington/L=Seattle/O=Hewlett Packard Enterprise/OU=Helion Cloud Foundry/CN=Intermediate Self-Signing Authority/' \
  -passin pass:foobar \
  -passout pass:foobar 

echo "Sign intermediate CA cert"

openssl ca -batch -config root_openssl.cnf -extensions v3_intermediate_ca \
  -days 3650 -notext -md sha256 \
  -passin pass:foobar \
  -in intermediate/csr/intermediate.csr.pem \
  -out intermediate/certs/intermediate.cert.pem
chmod 444 intermediate/certs/intermediate.cert.pem

echo "Intermediate CA created:"

openssl x509 -noout -text \
  -in intermediate/certs/intermediate.cert.pem  

cat intermediate/certs/intermediate.cert.pem \
  certs/ca.cert.pem > intermediate/certs/ca-chain.cert.pem  
chmod 444 intermediate/certs/ca-chain.cert.pem
