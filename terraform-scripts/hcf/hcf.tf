provider "openstack" {

}

resource "openstack_compute_secgroup_v2" "hcf-container-host-secgroup" {
    name = "${var.cluster-prefix}-container-host"
    description = "HCF Container Hosts"
    rule {
        from_port = 1
        to_port = 65535
        ip_protocol = "tcp"
        self = true
    }
    rule {
        from_port = 1
        to_port = 65535
        ip_protocol = "udp"
        self = true
    }
    rule {
        from_port = 22
        to_port = 22
        ip_protocol = "tcp"
        cidr = "0.0.0.0/0"
    }
    rule {
        from_port = 80
        to_port = 80
        ip_protocol = "tcp"
        cidr = "0.0.0.0/0"
    }
    rule {
        from_port = 443
        to_port = 443
        ip_protocol = "tcp"
        cidr = "0.0.0.0/0"
    }
    rule {
        from_port = 4443
        to_port = 4443
        ip_protocol = "tcp"
        cidr = "0.0.0.0/0"
    }
}

resource "openstack_networking_floatingip_v2" "hcf-core-host-fip" {
  pool = "${var.openstack_floating_ip_pool}"
}

resource "openstack_blockstorage_volume_v1" "hcf-core-vol" {
  name = "${var.cluster-prefix}-core-vol"
  description = "Helion Cloud Foundry Core"
  size = "${var.core_volume_size}"
  availability_zone = "${var.openstack_availability_zone}"
}

resource "openstack_compute_instance_v2" "hcf-core-host" {
    name = "${var.cluster-prefix}-core"
    flavor_id = "${var.openstack_flavor_id}"
    image_id = "${var.openstack_base_image_id}"
    key_pair = "${var.openstack_keypair}"
    security_groups = [ "default", "${openstack_compute_secgroup_v2.hcf-container-host-secgroup.id}" ]
    network = { uuid = "${var.openstack_network_id}" }
    availability_zone = "${var.openstack_availability_zone}"

	floating_ip = "${openstack_networking_floatingip_v2.hcf-core-host-fip.address}"

    volume = {
        volume_id = "${openstack_blockstorage_volume_v1.hcf-core-vol.id}"
    }

    connection {
        host = "${openstack_networking_floatingip_v2.hcf-core-host-fip.address}"
        user = "ubuntu"
        key_file = "${var.key_file}"
    }

    provisioner "remote-exec" {
        inline = [
        "mkdir /tmp/ca",
        "sudo mkdir -p /opt/hcf/bin",
        "sudo chown ubuntu:ubuntu /opt/hcf/bin"
        ]
    }

    # Install scripts and binaries
    provisioner "file" {
        source = "scripts/"
        destination = "/opt/hcf/bin/"
    }

    provisioner "remote-exec" {
      inline = [
      "sudo chmod ug+x /opt/hcf/bin/*",
      "echo 'export PATH=$PATH:/opt/hcf/bin' | sudo tee /etc/profile.d/hcf.sh"
      ]
    }

    provisioner "file" {
        source = "cert/"
        destination = "/tmp/ca/"
    }    

    provisioner "remote-exec" {
        inline = <<EOF
set -e
CERT_DIR=/home/ubuntu/ca

mv /tmp/ca $CERT_DIR
cd $CERT_DIR

bash generate_root.sh
bash generate_intermediate.sh

bash generate_host.sh ${var.cluster-prefix}-root "*.${openstack_networking_floatingip_v2.hcf-core-host-fip.address}.${var.domain}"

EOF
    }

    # format the blockstorage volume
    provisioner "remote-exec" {
        inline = <<EOF
set -e
DEVICE=$(http_proxy= curl -Ss --fail http://169.254.169.254/2009-04-04/meta-data/block-device-mapping/ebs0)
DEVICE1=$(http_proxy= curl -Ss --fail http://169.254.169.254/2009-04-04/meta-data/block-device-mapping/ebs0)1
echo Mounting at $DEVICE
sudo mkdir -p /data
sudo parted -s -- $DEVICE unit MB mklabel gpt
sudo parted -s -- $DEVICE unit MB mkpart primary 2048s -0
sudo mkfs.ext4 $DEVICE1
echo $DEVICE1 /data ext4 defaults,usrquota,grpquota 0 2 | sudo tee -a /etc/fstab
sudo mount /data
EOF
    }

    provisioner "remote-exec" {
        inline = <<EOF
set -e
echo "Install a kernel with quota support"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y linux-generic-lts-vivid linux-image-extra-virtual-lts-vivid
sudo reboot && sleep 10
EOF
    }        

    provisioner "remote-exec" {
        inline = <<EOF
set -e
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wget quota
sudo apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo deb https://apt.dockerproject.org/repo ubuntu-trusty main | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get purge -y lxc-docker*
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-engine=1.8.3-0~trusty
sudo usermod -aG docker ubuntu
# allow us to pull from the docker registry
# TODO: this needs to be removed when we publish to Docker Hub
echo DOCKER_OPTS=\"--insecure-registry ${var.registry_host} -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock -s devicemapper -g /data/docker\" | sudo tee -a /etc/default/docker

# enable cgroup memory and swap accounting
sudo sed -idockerbak 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"cgroup_enable=memory swapaccount=1\"/' /etc/default/grub
sudo update-grub

# We have to reboot since this switches our kernel.        
sudo reboot && sleep 10
EOF
    }

    #
    # gato
    #
    provisioner "remote-exec" {
        inline = ["docker pull ${var.registry_host}/hcf/hcf-gato"]
    }

    #
    # HCF consul
    #

    # configure consul
    provisioner "remote-exec" {
        inline = [
        "sudo mkdir -p /opt/hcf/etc",
        "sudo mkdir -p /data/hcf-consul",
        "sudo mkdir -p /data/cf-api",
        "sudo touch /data/cf-api/.nfs_test"
        ]
    }

    provisioner "file" {
        source = "config/consul.json"
        destination = "/tmp/consul.json"
    }

    # start the HCF consul server
    provisioner "remote-exec" {
        inline = [
        "sudo mv /tmp/consul.json /opt/hcf/etc/consul.json",
        "docker run -d --privileged --restart=always -p 8401:8401 -p 8501:8501 -p 8601:8601 -p 8310:8310 -p 8311:8311 -p 8312:8312 --name hcf-consul-server -v /opt/hcf/bin:/opt/hcf/bin -v /opt/hcf/etc:/opt/hcf/etc -v /data/hcf-consul:/opt/hcf/share/consul -t ${var.registry_host}/hcf/consul-server:latest -bootstrap -client=0.0.0.0 --config-file /opt/hcf/etc/consul.json"
        ]
    }

    provisioner "remote-exec" {
        inline = [
        "curl -L https://region-b.geo-1.objects.hpcloudsvc.com/v1/10990308817909/pelerinul/hcf.tar.gz -o /tmp/hcf-config-base.tgz",
        "bash /opt/hcf/bin/wait_for_consul.bash http://`/opt/hcf/bin/get_ip`:8501",
        "bash /opt/hcf/bin/consullin.bash http://`/opt/hcf/bin/get_ip`:8501 /tmp/hcf-config-base.tgz"
        ]
    }

    # Send script to set up consul-based services, health checks, and assign
    # monit ports (until we stop using docker --net host)
    provisioner "remote-exec" {
        inline = [
        "bash /opt/hcf/bin/service_registration.bash"
        ]
    }

    # Set the default configuration values for our cluster
    provisioner "remote-exec" {
        inline = <<EOF
#!/bin/bash
set -e        
export CONSUL=http://`/opt/hcf/bin/get_ip`:8501

/opt/hcf/bin/set-config $CONSUL hcf/user/consul/require_ssl false
/opt/hcf/bin/set-config $CONSUL hcf/user/consul/agent/servers/lan [\"`/opt/hcf/bin/get_ip`\"]
/opt/hcf/bin/set-config $CONSUL hcf/user/consul/encrypt_keys '[]'
/opt/hcf/bin/set-config $CONSUL hcf/role/consul/consul/agent/mode \"server\"

/opt/hcf/bin/set-config $CONSUL hcf/user/nats/user \"${var.nats_user}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/nats/password \"${var.nats_password}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/nats/machines '["nats.service.cf.internal"]'

/opt/hcf/bin/set-config $CONSUL hcf/user/etcd_metrics_server/nats/username \"${var.nats_user}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/etcd_metrics_server/password \"${var.nats_password}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/etcd_metrics_server/machines '["nats.service.cf.internal"]'

openssl genrsa -out ~/.ssh/jwt_signing.pem -passout pass:"${var.signing_key_passphrase}" 4096
openssl rsa -in ~/.ssh/jwt_signing.pem -outform PEM -passin pass:"${var.signing_key_passphrase}" -pubout -out ~/.ssh/jwt_signing.pub
/opt/hcf/bin/set-config-file $CONSUL hcf/user/uaa/jwt/signing_key ~/.ssh/jwt_signing.pem
/opt/hcf/bin/set-config-file $CONSUL hcf/user/uaa/jwt/verification_key ~/.ssh/jwt_signing.pub

# not setting these yet, since we're not using them.
# openssl genrsa -out ~/.ssh/service_provider.pem -passout pass:"${var.service_provider_key_passphrase}" 4096
# openssl rsa -in ~/.ssh/service_provider.pem -outform PEM -passin pass:"${var.service_provider_key_passphrase}" -pubout -out ~/.ssh/service_provider.pub
# /opt/hcf/bin/set-config-file $CONSUL hcf/user/login/saml/serviceProviderKey ~/.ssh/service_provider.pem
# /opt/hcf/bin/set-config-file $CONSUL hcf/user/login/saml/serviceProviderCertificate ~/.ssh/service_provider.pub

/opt/hcf/bin/set-config $CONSUL hcf/user/uaa/admin/client_secret \"${var.uaa_admin_client_secret}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/uaa/batch/username \"${var.uaa_batch_username}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/uaa/batch/password \"${var.uaa_batch_password}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/uaa/cc/client_secret \"${var.uaa_cc_client_secret}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/uaa/clients/app-direct/secret \"${var.uaa_clients_app-direct_secret}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/uaa/clients/developer-console/secret \"${var.uaa_clients_developer_console_secret}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/uaa/clients/notifications/secret \"${var.uaa_clients_notifications_secret}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/uaa/clients/login/secret \"${var.uaa_clients_login_secret}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/uaa/clients/doppler/secret \"${var.uaa_clients_doppler_secret}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/uaa/clients/cloud_controller_username_lookup/secret \"${var.uaa_cloud_controller_username_lookup_secret}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/uaa/clients/gorouter/secret \"${var.uaa_clients_gorouter_secret}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/uaa/scim/users '${var.uaa_scim_users}'

/opt/hcf/bin/set-config $CONSUL hcf/user/uaadb/roles '[{"name": "${var.uaadb_username}", "password": "${var.uaadb_password}", "tag": "${var.uaadb_tag}"}]'
/opt/hcf/bin/set-config $CONSUL hcf/user/domain \"${openstack_networking_floatingip_v2.hcf-core-host-fip.address}.${var.domain}\"

/opt/hcf/bin/set-config $CONSUL hcf/user/doppler/zone \"${var.doppler_zone}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/traffic_controller/zone \"${var.traffic_controller_zone}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/metron_agent/zone \"${var.metron_agent_zone}\"

/opt/hcf/bin/set-config $CONSUL hcf/user/cc/bulk_api_password \"${var.bulk_api_password}\"

# combine the certs, so we can insert them into ha_proxy's config
TEMP_CERT=$(mktemp --suffix=.pem)

cat /home/ubuntu/ca/intermediate/private/${var.cluster-prefix}-root.key.pem > $TEMP_CERT
cat /home/ubuntu/ca/intermediate/certs/${var.cluster-prefix}-root.cert.pem >> $TEMP_CERT

/opt/hcf/bin/set-config-file $CONSUL hcf/user/ha_proxy/ssl_pem $TEMP_CERT

rm $TEMP_CERT

/opt/hcf/bin/set-config $CONSUL hcf/user/loggregator_endpoint/shared_secret \"${var.loggregator_shared_secret}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/doppler_endpoint/shared_secret \"${var.loggregator_shared_secret}\"

/opt/hcf/bin/set-config $CONSUL hcf/user/ccdb/roles '[{"name": "${var.ccdb_role_name}", "password": "${var.ccdb_role_password}", "tag": "${var.ccdb_role_tag}"}]'

# TODO: replace this with Swift settings
# /opt/hcf/bin/set-config $CONSUL hcf/user/cc/resource_pool/fog_connection '{}'
# /opt/hcf/bin/set-config $CONSUL hcf/user/cc/packages/fog_connection '{}'
# /opt/hcf/bin/set-config $CONSUL hcf/user/cc/droplets/fog_connection '{}'
# /opt/hcf/bin/set-config $CONSUL hcf/user/cc/buildpacks/fog_connection '{}'
/opt/hcf/bin/set-config $CONSUL hcf/user/cc/db_encryption_key \"${var.db_encryption_key}\"

/opt/hcf/bin/set-config $CONSUL hcf/user/app_domains '["${openstack_networking_floatingip_v2.hcf-core-host-fip.address}.${var.domain}"]'
/opt/hcf/bin/set-config $CONSUL hcf/user/system_domain \"${openstack_networking_floatingip_v2.hcf-core-host-fip.address}.${var.domain}\"

/opt/hcf/bin/set-config $CONSUL hcf/user/ccdb/address \"postgres.service.cf.internal\"
/opt/hcf/bin/set-config $CONSUL hcf/user/databases/address \"postgres.service.cf.internal\"
/opt/hcf/bin/set-config $CONSUL hcf/user/uaadb/address \"postgres.service.cf.internal\"

/opt/hcf/bin/set-config $CONSUL hcf/role/uaa/consul/agent/services/uaa '{}'
/opt/hcf/bin/set-config $CONSUL hcf/role/api/consul/agent/services/cloud_controller_ng '{}'
/opt/hcf/bin/set-config $CONSUL hcf/role/api/consul/agent/services/routing_api '{}'
/opt/hcf/bin/set-config $CONSUL hcf/role/router/consul/agent/services/gorouter '{}'
/opt/hcf/bin/set-config $CONSUL hcf/role/nats/consul/agent/services/nats '{}'
/opt/hcf/bin/set-config $CONSUL hcf/role/postgres/consul/agent/services/postgres '{}'
/opt/hcf/bin/set-config $CONSUL hcf/role/etcd/consul/agent/services/etcd '{}'

/opt/hcf/bin/set-config $CONSUL hcf/user/databases/address \"postgres.service.cf.internal\"
/opt/hcf/bin/set-config $CONSUL hcf/user/databases/databases '[{"citext":true, "name":"ccdb", "tag":"cc"}, {"citext":true, "name":"uaadb", "tag":"uaa"}]' http://127.0.0.1:8501/v1/kv/
/opt/hcf/bin/set-config $CONSUL hcf/user/databases/port '5524'
/opt/hcf/bin/set-config $CONSUL hcf/user/databases/roles '[{"name": "${var.ccdb_role_name}", "password": "${var.ccdb_role_password}","tag": "${var.ccdb_role_tag}"}, {"name": "${var.uaadb_username}", "password": "${var.uaadb_password}", "tag":"${var.uaadb_tag}"}]'  http://127.0.0.1:8501/v1/kv/

/opt/hcf/bin/set-config $CONSUL hcf/user/cc/staging_upload_user \"${var.staging_upload_user}\"
/opt/hcf/bin/set-config $CONSUL hcf/user/cc/staging_upload_password \"${var.staging_upload_password}\"

/opt/hcf/bin/set-config $CONSUL hcf/user/etcd/machines '["etcd.service.cf.internal"]'
/opt/hcf/bin/set-config $CONSUL hcf/user/router/servers/z1 '["gorouter.service.cf.internal"]'

/opt/hcf/bin/set-config $CONSUL hcf/role/runner/consul/agent/services/dea_next '{}'

/opt/hcf/bin/set-config $CONSUL hcf/user/dea_next/kernel_network_tuning_enabled 'false'

/opt/hcf/bin/set-config $CONSUL hcf/user/cc/srv_api_uri \"https://api.${openstack_networking_floatingip_v2.hcf-core-host-fip.address}.${var.domain}\"
# TODO: Take this out, and place our generated CA cert into the appropriate /usr/share/ca-certificates folders
# and call update-ca-certificates at container startup
/opt/hcf/bin/set-config $CONSUL hcf/user/ssl/skip_cert_verify 'true'

/opt/hcf/bin/set-config $CONSUL hcf/user/disk_quota_enabled 'false'

# TODO: This should be handled in the 'opinions' file, since the ERb templates will generate this value
curl -X DELETE $CONSUL/v1/kv/hcf/opinions/hm9000/url
curl -X DELETE $CONSUL/v1/kv/hcf/opinions/uaa/url

/opt/hcf/bin/set-config $CONSUL hcf/user/metron_agent/deployment \"hcf-deployment\"

EOF
    }    

    #
    # run the CF components in a container
    #
    # --cgroup-parent=instance exists because CF has code to detect that it's running in a warden container, otherwise
    # it will attempt to modify iptables and the /proc file system, which is not allowed in a container. This changes
    # the Docker cgroup parent name to /instance instead of /docker.

    # start the CF consul server
    #
    provisioner "remote-exec" {
        inline = [
        "sudo mkdir -p /data/cf-consul"
        ]
    }

    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2830:2830 -p 8301:8301 -p 8302:8302 -p 8400:8400 -p 8500:8500 -p 8600:8600 --name cf-consul -v /data/cf-consul:/var/vcap/store -t ${var.registry_host}/hcf/cf-v${var.cf-release}-consul:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 2"
        ]
    }

    #
    # api
    #

    # start the api server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2837:2837 -p 9022:9022 --name cf-api -v /data/cf-api:/var/vcap/nfs/shared -t ${var.registry_host}/hcf/cf-v${var.cf-release}-api:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 0"
        ]        
    }

    #
    # nats
    #

    # start the nats server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2831:2831 -p 4222:4222 -p 6222:6222 -p 8222:8222 --name cf-nats -t ${var.registry_host}/hcf/cf-v${var.cf-release}-nats:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 1"
        ]
    }

    #
    # etcd
    #

    # start the etcd server
    provisioner "remote-exec" {
        inline = [
        "sudo mkdir -p /data/cf-etcd"
        ]
    }

    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2832:2832 -p 2379:2379 -p 2380:2380 --name cf-etcd -v /data/cf-etcd:/var/vcap/store -t ${var.registry_host}/hcf/cf-v${var.cf-release}-etcd:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 3"
        ]
    }

    #
    # postgresql
    #

    # start the postgresql server
    provisioner "remote-exec" {
        inline = [
        "sudo mkdir -p /data/cf-postgres"
        ]
    }

    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2835:2835 -p 5432:5432 -p 5542:5542 --name cf-postgres -v /data/cf-postgres:/var/vcap/store -t ${var.registry_host}/hcf/cf-v${var.cf-release}-postgres:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 4"
        ]        
    }

    #
    # stats
    #

    # start the stats server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2833:2833 --name cf-stats -t ${var.registry_host}/hcf/cf-v${var.cf-release}-stats:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 5"
        ]        
    }

    #
    # ha_proxy
    #

    # start the ha_proxy server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2834:2834 -p 80:80 -p 443:443 -p 4443:4443 --name cf-ha_proxy -t ${var.registry_host}/hcf/cf-v${var.cf-release}-ha_proxy:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 6"
        ]        
    }

    #
    # uaa
    #

    # start the uaa server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2836:2836 -p 8080:8080 --name cf-uaa -t ${var.registry_host}/hcf/cf-v${var.cf-release}-uaa:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 7"
        ]        
    }

    #
    # clock_global
    #

    # start the clock_global server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2838:2838 --name cf-clock_global -t ${var.registry_host}/hcf/cf-v${var.cf-release}-clock_global:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 9"
        ]        
    }

    #
    # api_worker
    #

    # start the api_worker server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2839:2839 --name cf-api_worker -v /data/cf-api:/var/vcap/nfs/shared -t ${var.registry_host}/hcf/cf-v${var.cf-release}-api_worker:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 10"
        ]        
    }

    #
    # hm9000
    #

    # start the hm9000 server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2840:2840 --name cf-hm9000 -t ${var.registry_host}/hcf/cf-v${var.cf-release}-hm9000:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 11"
        ]        
    }

    #
    # doppler
    #

    # start the doppler server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2841:2841 --name cf-doppler -t ${var.registry_host}/hcf/cf-v${var.cf-release}-doppler:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 12"
        ]        
    }

    #
    # loggregator_trafficcontroller
    #

    # start the loggregator_trafficcontroller server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2842:2842 --name cf-loggregator_trafficcontroller -t ${var.registry_host}/hcf/cf-v${var.cf-release}-loggregator_trafficcontroller:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 14"
        ]        
    }

    #
    # router
    #

    # start the router server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2843:2843 --name cf-router -t ${var.registry_host}/hcf/cf-v${var.cf-release}-router:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 15"
        ]        
    }

    #
    # runner
    #

    # start the runner server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --privileged --cap-add=ALL -v /lib/modules:/lib/modules --cgroup-parent=instance --restart=always --dns=127.0.0.1 --dns=${var.dns_server} -p 2844:2844 --name cf-runner -t ${var.registry_host}/hcf/cf-v${var.cf-release}-runner:latest http://`/opt/hcf/bin/get_ip`:8501 hcf 16"
        ]        
    }
}
