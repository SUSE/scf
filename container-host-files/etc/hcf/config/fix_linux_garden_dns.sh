set -e

GARDEN_LINUX_DNS_SERVER=${GARDEN_LINUX_DNS_SERVER:-8.8.8.8}

read -d '' setup_patch <<PATCH || true
--- setup.sh	2016-01-05 03:55:59.000000000 -0800
+++ setup_patched.sh	2016-02-10 21:05:10.000000000 -0800
@@ -128,10 +128,10 @@
 # assumed to be running its own DNS server and listening on all interfaces.
 # In this case, the container must use the network_host_ip address
 # as the nameserver.
-if [[ "\$(cat /etc/resolv.conf)" == "nameserver 127.0.0.1" ]]
+if [[ "\$(cat /etc/resolv.conf)" == *"nameserver 127.0.0."* ]]
 then
   cat > \$rootfs_path/etc/resolv.conf <<-EOS
-nameserver \$network_host_ip
+nameserver ${GARDEN_LINUX_DNS_SERVER}
 EOS
 else
   # some images may have something set up here; the host's should be the source
PATCH

cd /var/vcap/packages/garden-linux/src/github.com/cloudfoundry-incubator/garden-linux/linux_backend/skeleton/
echo -e "${setup_patch}" | patch --batch

exit 0
