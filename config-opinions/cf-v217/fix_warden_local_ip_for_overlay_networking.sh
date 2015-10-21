set -e

if [[ "${HCF_NETWORK}" -ne "overlay" ]]; then
  exit 0
fi

cd /var/vcap/packages/

find . -name net.sh -exec sed -ibak 's/8\.8\.8\.8/1\.2\.3\.4/g' {} \;

exit 0
