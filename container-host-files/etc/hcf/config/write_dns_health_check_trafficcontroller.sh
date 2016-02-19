set -e

mkdir -p /var/vcap/jobs/loggregator_trafficcontroller/bin/

cat > /var/vcap/jobs/loggregator_trafficcontroller/bin/dns_health_check <<EOF
  exit 0
EOF

chmod +x /var/vcap/jobs/loggregator_trafficcontroller/bin/dns_health_check
