#!/bin/bash
set -e

KEY_NAME=$1
HOSTNAME=$2

if [ -f intermediate/private/$KEY_NAME.key.pem ] ; then
  rm -f intermediate/private/$KEY_NAME.key.pem
fi

if [ -f intermediate/csr/$KEY_NAME.csr.pem ] ; then
  rm -f intermediate/csr/$KEY_NAME.csr.pem
fi

if [ -f intermediate/certs/$KEY_NAME.cert.pem ] ; then
  rm -f intermediate/certs/$KEY_NAME.cert.pem
fi

openssl genrsa -out intermediate/private/$KEY_NAME.key.pem 2048
chmod 400 intermediate/private/$KEY_NAME.key.pem

TEMP_CONF=$(mktemp --suffix=.cnf)

cat intermediate_openssl.cnf >> $TEMP_CONF
cat >> $TEMP_CONF <<EOF

[ san_env ]
subjectAltName=DNS:$HOSTNAME
EOF

echo "Generate host CSR named $KEY_NAME for $HOSTNAME"

openssl req -config $TEMP_CONF \
  -key intermediate/private/$KEY_NAME.key.pem \
  -new -sha256 -out intermediate/csr/$KEY_NAME.csr.pem \
  -subj "/C=US/ST=Washington/L=Seattle/O=Hewlett Packard Enterprise/OU=Helion Cloud Foundry/CN=${HOSTNAME}" \
  -extensions san_env \
  -passin pass:foobar \
  -passout pass:foobar 

echo "Sign host certificate"

openssl ca -batch -config $TEMP_CONF \
  -extensions server_cert -days 3650 -notext -md sha256 \
  -in intermediate/csr/$KEY_NAME.csr.pem \
  -out intermediate/certs/$KEY_NAME.cert.pem \
  -passin pass:foobar 
chmod 444 intermediate/certs/$KEY_NAME.cert.pem  

echo "Verify host certificate against CA chain"
openssl verify -CAfile intermediate/certs/ca-chain.cert.pem \
  intermediate/certs/$KEY_NAME.cert.pem

echo "Host certificate generated:"
openssl x509 -noout -text \
  -in intermediate/certs/$KEY_NAME.cert.pem

rm $TEMP_CONF