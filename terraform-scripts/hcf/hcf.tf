# © Copyright 2015 Hewlett Packard Enterprise Development LP

provider "openstack" {

}

resource "template_file" "domain" {
    template = "${path.module}/../templates/domain.tpl"

    vars {
        domain = "${var.domain}"
        floating_domain = "${openstack_networking_floatingip_v2.hcf-core-host-fip.address}.${var.domain}"
        wildcard_dns = "${var.wildcard_dns}"
    }
}

resource "template_file" "gato_wrapper" {
    template = "${path.module}/../templates/gato-wrapper.tpl"

    vars {
        gato-build = "${var.gato-build}"
    }
}

resource "template_file" "run-acceptance-tests" {
    template = "${path.module}/../templates/run-acceptance-tests.bash.tpl"

    vars {
        build = "${var.build}"
    }
}

resource "template_file" "run-smoke-tests" {
    template = "${path.module}/../templates/run-smoke-tests.bash.tpl"

    vars {
        build = "${var.build}"
    }
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
    flavor_id = "${var.openstack_flavor_id.core}"
    image_id = "${lookup(var.openstack_base_image_id, var.openstack_region)}"
    key_pair = "${var.openstack_keypair}"
    security_groups = [ "default", "${openstack_compute_secgroup_v2.hcf-container-host-secgroup.id}" ]
    network = { 
        uuid = "${var.openstack_network_id}"
        name = "${var.openstack_network_name}"
    }
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
        source = "${path.module}/../../container-host-files/opt/hcf/bin/"
        destination = "/opt/hcf/bin/"
    }

    provisioner "remote-exec" {
        inline = [
            "cat > /opt/hcf/bin/gato <<'EOF'",
            "${template_file.gato_wrapper.rendered}",
            "EOF"
        ]
    }

    provisioner "remote-exec" {
        inline = [
            "cat > /opt/hcf/bin/run-acceptance-tests.bash <<'EOF'",
            "${template_file.run-acceptance-tests.rendered}",
            "EOF"
        ]
    }

    provisioner "remote-exec" {
        inline = [
            "cat > /opt/hcf/bin/run-smoke-tests.bash <<'EOF'",
            "${template_file.run-smoke-tests.rendered}",
            "EOF"
        ]
    }

    provisioner "remote-exec" {
      inline = [
      "sudo chmod ug+x /opt/hcf/bin/* /opt/hcf/bin/docker/*",
      "echo 'export PATH=$PATH:/opt/hcf/bin:/opt/hcf/bin/docker' | sudo tee /etc/profile.d/hcf.sh"
      ]
    }

    provisioner "file" {
        source = "${path.module}/../../container-host-files/opt/hcf/bin/cert/"
        destination = "/tmp/ca/"
    }    

    provisioner "remote-exec" {
        inline = <<EOF
set -e
CERT_DIR=/home/ubuntu/.run/certs/ca

mkdir -p $(dirname $CERT_DIR)
mv /tmp/ca $CERT_DIR
cd $CERT_DIR

bash generate_root.sh
bash generate_intermediate.sh

bash generate_host.sh ${var.cluster-prefix}-root "*.${template_file.domain.rendered}"

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
        inline = [
	    "bash -e /opt/hcf/bin/docker/install_kernel.sh"
	]
    }        

    provisioner "remote-exec" {
        inline = [
          "bash -e /opt/hcf/bin/docker/install_etcd.sh"
        ]
    }        

    provisioner "file" {
        source = "${path.module}/../../container-host-files/etc/init/etcd.conf"
        destination = "/tmp/etcd.conf"
    }

    provisioner "remote-exec" {
        inline = [
          "bash -e /opt/hcf/bin/docker/configure_etcd.sh ${var.cluster-prefix} ${openstack_compute_instance_v2.hcf-core-host.network.0.fixed_ip_v4}"
        ]
    }

    provisioner "file" {
        source = "${path.module}/../../container-host-files/opt/hcf/keys/docker.gpg"
        destination = "/tmp/docker.gpg"
    }

    provisioner "remote-exec" {
        inline = <<EOF
set -e
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wget quota

echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" | sudo tee /etc/apt/sources.list.d/docker.list

sudo apt-key add /tmp/docker.gpg
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-engine=${var.docker_version}

sudo usermod -aG docker ubuntu

bash -e /opt/hcf/bin/docker/configure_docker.sh ${openstack_compute_instance_v2.hcf-core-host.network.0.fixed_ip_v4}

# We have to reboot since this switches our kernel.
sudo reboot && sleep 10
EOF
    }

    # 
    # sign in to docker hub if username / password is provided
    #
    provisioner "remote-exec" {
        inline = <<EOF
set -e

DOCKER_USERNAME=${var.docker_username}

if [ "$DOCKER_USERNAME" != "" ] ; then
    echo "Logging in to Docker Hub for image pulls"

    docker login "-e=${var.docker_email}" "-u=${var.docker_username}" "-p=${var.docker_password}"
fi

EOF
    }

    #
    # gato
    #
    provisioner "remote-exec" {
        inline = ["docker pull helioncf/hcf-gato:${var.build} | tee /tmp/hcf-gato-output"]
    }

    #
    # configure Docker overlay network
    #
    provisioner "remote-exec" {
        inline = [
          "bash -e /opt/hcf/bin/docker/setup_overlay_network.sh ${var.overlay_subnet} ${var.overlay_gateway}"
        ]
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

    # start the HCF consul server
    provisioner "remote-exec" {
        inline = <<EOF
set -e
cid=$(docker run -d --net=bridge --privileged=true --restart=unless-stopped -p 8401:8401 -p 8501:8501 -p 8601:8601 -p 8310:8310 -p 8311:8311 -p 8312:8312 --name hcf-consul-server -v /data/hcf-consul:/opt/hcf/share/consul -t helioncf/hcf-consul-server:${var.build} -bootstrap -client=0.0.0.0 --config-file /opt/hcf/etc/consul.json | tee /tmp/hcf-consul-server-output)
docker network connect hcf $cid
EOF
    }

    provisioner "file" {
        source = "hcf-config.tar.gz"
        destination = "/tmp/hcf-config.tar.gz"
    }

    provisioner "remote-exec" {
        inline = [
        "bash /opt/hcf/bin/wait_for_consul.bash http://`/opt/hcf/bin/get_ip`:8501",
        "bash /opt/hcf/bin/consullin.bash http://`/opt/hcf/bin/get_ip`:8501 /tmp/hcf-config.tar.gz"
        ]
    }

    # Set the default configuration values for our cluster
    provisioner "remote-exec" {
        inline = <<EOF
set -ex

# Full path needed to gato because we're running this via terraform,
# and the path doesn't include /opt/hcf/bin
OPTDIR=/opt/hcf/bin
$OPTDIR/gato api http://hcf-consul-server.hcf:8501
env bulk_api_password='${var.bulk_api_password}' \
    ccdb_role_name='${var.ccdb_role_name}' \
    certs_prefix='${var.cluster-prefix}' \
    ccdb_role_password='${var.ccdb_role_password}' \
    cluster_admin_authorities='${var.cluster_admin_authorities}' \
    cluster_admin_password='${var.cluster_admin_password}' \
    cluster_admin_username='${var.cluster_admin_username}' \
    db_encryption_key='${var.db_encryption_key}' \
    dea_count='${var.dea_count}' \
    domain='${template_file.domain.rendered}' \
    doppler_zone='${var.doppler_zone}' \
    loggregator_shared_secret='${var.loggregator_shared_secret}' \
    metron_agent_zone='${var.metron_agent_zone}' \
    monit_password='${var.monit_password}' \
    monit_port='${var.monit_port}' \
    monit_user='${var.monit_user}' \
    nats_password='${var.nats_password}' \
    nats_user='${var.nats_user}' \
    service_provider_key_passphrase='${var.service_provider_key_passphrase}' \
    signing_key_passphrase='${var.signing_key_passphrase}' \
    staging_upload_user='${var.staging_upload_user}' \
    staging_upload_password='${var.staging_upload_password}' \
    traffic_controller_zone='${var.traffic_controller_zone}' \
    uaa_admin_client_secret='${var.uaa_admin_client_secret}' \
    uaa_cc_client_secret='${var.uaa_cc_client_secret}' \
    uaa_clients_app_direct_secret='${var.uaa_clients_app-direct_secret}' \
    uaa_clients_cc_routing_secret='${var.uaa_clients_cc_routing_secret}' \
    uaa_clients_developer_console_secret='${var.uaa_clients_developer_console_secret}' \
    uaa_clients_doppler_secret='${var.uaa_clients_doppler_secret}' \
    uaa_clients_gorouter_secret='${var.uaa_clients_gorouter_secret}' \
    uaa_clients_login_secret='${var.uaa_clients_login_secret}' \
    uaa_clients_notifications_secret='${var.uaa_clients_notifications_secret}' \
    uaa_cloud_controller_username_lookup_secret='${var.uaa_cloud_controller_username_lookup_secret}' \
    uaadb_password='${var.uaadb_password}' \
    uaadb_username='${var.uaadb_username}' \
    $OPTDIR/configs.sh

# And these things didn't work in configs.sh, so leave them here:

set -e
export CONSUL=http://`/opt/hcf/bin/get_ip`:8501
# Keep this -- otherwise the routing-api component of cf-api fails with the error:
# Public uaa token must be PEM encoded
openssl genrsa -out ~/.ssh/jwt_signing.pem -passout pass:"${var.signing_key_passphrase}" 4096
openssl rsa -in ~/.ssh/jwt_signing.pem -outform PEM -passin pass:"${var.signing_key_passphrase}" -pubout -out ~/.ssh/jwt_signing.pub
/opt/hcf/bin/set-config-file $CONSUL hcf/user/uaa/jwt/signing_key ~/.ssh/jwt_signing.pem
/opt/hcf/bin/set-config-file $CONSUL hcf/user/uaa/jwt/verification_key ~/.ssh/jwt_signing.pub

# Keep this -- otherwise the ha_proxy role gives error mesages of the form:
# parsing [/var/vcap/jobs/haproxy/config/haproxy.conf:31] : 'bind :443' : 
# unable to load SSL private key from PEM file '/var/vcap/jobs/haproxy/config/cert.pem'.
# The problem here is that the 2 parts of the generated key aren't separated
# by a newline:
# 
# cat /var/vcap/jobs/haproxy/config/cert.pem
# ...
# ... Z9Is -----END RSA PRIVATE KEY----- -----BEGIN CERTIFICATE----- MIIGFz ...
# ...

# combine the certs, so we can insert them into ha_proxy's config
TEMP_CERT=$(mktemp --suffix=.pem)
cat /home/ubuntu/.run/certs/ca/intermediate/private/${var.cluster-prefix}-root.key.pem > $TEMP_CERT
cat /home/ubuntu/.run/certs/ca/intermediate/certs/${var.cluster-prefix}-root.cert.pem >> $TEMP_CERT
/opt/hcf/bin/set-config-file $CONSUL hcf/user/ha_proxy/ssl_pem $TEMP_CERT
rm $TEMP_CERT

EOF
    }

    # Register the services we expect to be alive and health checks for them.
    provisioner "remote-exec" {
        inline = [
        "bash /opt/hcf/bin/service_registration.bash \"${var.dea_count}\""
        ]
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
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-consul -v /data/cf-consul:/var/vcap/store -t helioncf/cf-consul:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-consul-output"
        ]
    }

    #
    # api
    #

    # start the api server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-api -v /data/cf-api:/var/vcap/nfs/shared -t helioncf/cf-api:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-api-output"
        ]        
    }

    #
    # nats
    #

    # start the nats server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-nats -t helioncf/cf-nats:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-nats-output"
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
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-etcd -v /data/cf-etcd:/var/vcap/store -t helioncf/cf-etcd:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-etcd-output"
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
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-postgres -v /data/cf-postgres:/var/vcap/store -t helioncf/cf-postgres:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-postgres-output"
        ]        
    }

    #
    # stats
    #

    # start the stats server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-stats -t helioncf/cf-stats:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-stats-output"
        ]        
    }

    #
    # router
    #

    # start the router server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-router -t helioncf/cf-router:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-router-output"
        ]        
    }

    #
    # ha_proxy - this depends on gorouter, so make a best effort to start router before this.
    #

    # start the ha_proxy server
    provisioner "remote-exec" {
        inline = <<EOF
set -e
cid=$(docker run -d --net=bridge -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} -p 80:80 -p 443:443 -p 4443:4443 --name cf-ha_proxy -t helioncf/cf-ha_proxy:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-haproxy-output)
docker network connect hcf $cid
EOF
    }

    #
    # uaa
    #

    # start the uaa server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-uaa -t helioncf/cf-uaa:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-uaa-output"
        ]        
    }

    #
    # clock_global
    #

    # start the clock_global server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-clock_global -t helioncf/cf-clock_global:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-clock_global-output"
        ]        
    }

    #
    # api_worker
    #

    # start the api_worker server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-api_worker -v /data/cf-api:/var/vcap/nfs/shared -t helioncf/cf-api_worker:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-api_worker-output"
        ]        
    }

    #
    # hm9000
    #

    # start the hm9000 server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-hm9000 -t helioncf/cf-hm9000:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-hm9000-output"
        ]        
    }

    #
    # doppler
    #

    # start the doppler server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-doppler -t helioncf/cf-doppler:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-doppler-output"
        ]        
    }

    #
    # loggregator_trafficcontroller
    #

    # start the loggregator_trafficcontroller server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-loggregator_trafficcontroller -t helioncf/cf-loggregator_trafficcontroller:${var.build} http://hcf-consul-server.hcf:8501 hcf 0 | tee /tmp/cf-loggregator_trafficcontroller-output"
        ]        
    }
}

resource "openstack_compute_instance_v2" "hcf-dea-host" {
    name = "${var.cluster-prefix}-dea-${count.index}"
    flavor_id = "${var.openstack_flavor_id.dea}"
    image_id = "${lookup(var.openstack_base_image_id, var.openstack_region)}"
    key_pair = "${var.openstack_keypair}"
    security_groups = [ "default", "${openstack_compute_secgroup_v2.hcf-container-host-secgroup.id}" ]
    network = { 
        uuid = "${var.openstack_network_id}"
        name = "${var.openstack_network_name}"
    }
    availability_zone = "${var.openstack_availability_zone}"
    count = "${var.dea_count}"

    connection {
        user = "ubuntu"
        key_file = "${var.key_file}"

        bastion_host = "${openstack_compute_instance_v2.hcf-core-host.access_ip_v4}"
    }

    provisioner "remote-exec" {
        inline = [
        "sudo mkdir -p /opt/hcf/bin",
        "sudo chown ubuntu:ubuntu /opt/hcf/bin"
        ]
    }

    # Install scripts and binaries
    provisioner "file" {
        source = "${path.module}/../../container-host-files/opt/hcf/bin/"
        destination = "/opt/hcf/bin/"
    }

    provisioner "remote-exec" {
      inline = [
      "sudo chmod ug+x /opt/hcf/bin/*",
      "echo 'export PATH=$PATH:/opt/hcf/bin' | sudo tee /etc/profile.d/hcf.sh"
      ]
    }

    provisioner "remote-exec" {
        inline = [
	    "bash -e /opt/hcf/bin/docker/install_kernel.sh"
	]
    }        

    provisioner "file" {
        source = "${path.module}/../../container-host-files/opt/hcf/keys/docker.gpg"
        destination = "/tmp/docker.gpg"
    }

    provisioner "remote-exec" {
        inline = <<EOF
set -e
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wget quota

echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" | sudo tee /etc/apt/sources.list.d/docker.list

sudo apt-key add /tmp/docker.gpg
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-engine=${var.docker_version}

sudo usermod -aG docker ubuntu

bash -e /opt/hcf/bin/docker/configure_docker.sh ${openstack_compute_instance_v2.hcf-core-host.network.0.fixed_ip_v4} ${self.network.0.fixed_ip_v4}
sudo reboot && sleep 10
EOF
    }

    # 
    # sign in to docker hub if username / password is provided
    #
    provisioner "remote-exec" {
        inline = <<EOF
set -e

DOCKER_USERNAME=${var.docker_username}

if [ "$DOCKER_USERNAME" != "" ] ; then
    echo "Logging in to Docker Hub for image pulls"

    docker login "-e=${var.docker_email}" "-u=${var.docker_username}" "-p=${var.docker_password}"
fi

EOF
    }

    #
    # gato
    #
    provisioner "remote-exec" {
        inline = ["docker pull helioncf/hcf-gato:${var.build} | tee /tmp/hcf-gato-output"]
    }
    
    #
    # acceptance test image
    #
    provisioner "remote-exec" {
        inline = ["docker pull helioncf/cf-acceptance_tests:${var.build} | tee /tmp/hcf-acceptance_tests-output"]
    }

    #
    # smoke test image
    #
    provisioner "remote-exec" {
        inline = ["docker pull helioncf/cf-smoke_tests:${var.build} | tee /tmp/hcf-smoke_tests-output"]
    }

    #
    # runner
    #

    # start the runner server
    provisioner "remote-exec" {
        inline = [
        "docker run -d --net=hcf -e 'HCF_NETWORK=overlay' -e 'HCF_OVERLAY_GATEWAY=${var.overlay_gateway}' --privileged=true --cap-add=ALL -v /lib/modules:/lib/modules --cgroup-parent=instance --restart=unless-stopped --dns=127.0.0.1 --dns=${var.dns_server} --name cf-runner-${count.index} -t helioncf/cf-runner:${var.build} http://hcf-consul-server.hcf:8501 hcf ${count.index} | tee /tmp/cf-runner-${count.index}-output"
        ]        
    }
}
