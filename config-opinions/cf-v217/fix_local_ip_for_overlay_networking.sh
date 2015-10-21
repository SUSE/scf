set -e

if [[ "${HCF_NETWORK}" -ne "overlay" ]]; then
  exit 0
fi

route add 198.41.0.4 gw 192.168.252.1 dev eth0
route add 1.2.3.4 gw 192.168.252.1 dev eth0

exit 0
