set -e

if [[ "${HCF_NETWORK}" -ne "overlay" ]]; then
  exit 0
fi

if [[ -z "${HCF_OVERLAY_GATEWAY}" ]]; then
  echo "Missing HCF_OVERLAY_GATEWAY environment variable."
  exit 1
fi

route add 198.41.0.4 gw $HCF_OVERLAY_GATEWAY dev eth0
route add 1.2.3.4 gw $HCF_OVERLAY_GATEWAY dev eth0

exit 0
