set -e

cat > /var/vcap/jobs/cf_console/bin/dns_health_check <<EOF
  exit 0
EOF

chmod +x /var/vcap/jobs/cf_console/bin/dns_health_check
