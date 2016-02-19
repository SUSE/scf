set -e

mkdir -p /var/vcap/jobs/nats/bin/

cat > /var/vcap/jobs/nats/bin/dns_health_check <<EOF
  exit 0
EOF

chmod +x /var/vcap/jobs/nats/bin/dns_health_check
