set -e

cat > /var/vcap/jobs/collector/bin/dns_health_check <<EOF
  exit 0
EOF

chmod +x /var/vcap/jobs/collector/bin/dns_health_check

