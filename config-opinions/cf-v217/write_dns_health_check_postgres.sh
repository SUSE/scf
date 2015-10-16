set -e

cat > /var/vcap/jobs/postgres/bin/dns_health_check <<EOF
  exit 0
EOF

chmod +x /var/vcap/jobs/postgres/bin/dns_health_check

