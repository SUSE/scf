set -e

mkdir -p /var/vcap/jobs/mysql_proxy/bin

cat > /var/vcap/jobs/mysql_proxy/bin/dns_health_check <<EOF
  exit 0
EOF

chmod +x /var/vcap/jobs/mysql_proxy/bin/dns_health_check
