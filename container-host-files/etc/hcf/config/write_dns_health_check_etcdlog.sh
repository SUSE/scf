set -e

mkdir -p /var/vcap/jobs/etcdlog/bin

cat > /var/vcap/jobs/etcdlog/bin/dns_health_check <<EOF
  exit 0
EOF

chmod +x /var/vcap/jobs/etcdlog/bin/dns_health_check
