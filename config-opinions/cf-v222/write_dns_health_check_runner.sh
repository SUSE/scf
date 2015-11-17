set -e

cat > /var/vcap/jobs/dea_next/bin/dns_health_check <<EOF
  exit 0
EOF

chmod +x /var/vcap/jobs/dea_next/bin/dns_health_check

