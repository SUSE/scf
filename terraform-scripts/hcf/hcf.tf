provider "openstack" {

}

resource "openstack_compute_secgroup_v2" "hcf-container-host-secgroup" {
    name = "hcf-container-host"
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
}

resource "openstack_networking_floatingip_v2" "hcf-core-host-fip" {
  pool = "${var.openstack_floating_ip_pool}"
}

resource "openstack_blockstorage_volume_v1" "hcf-core-vol" {
  name = "hcf-core-vol"
  description = "Helion Cloud Foundry Core"
  size = "${var.core_volume_size}"
  availability_zone = "${var.openstack_availability_zone}"
}

resource "openstack_compute_instance_v2" "hcf-core-host" {
    name = "hcf_core"
    flavor_id = "${var.openstack_flavor_id}"
    image_id = "${var.openstack_base_image_id}"
    key_pair = "${var.openstack_keypair}"
    security_groups = [ "default", "${openstack_compute_secgroup_v2.hcf-container-host-secgroup.name}" ]
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
        "mkdir /tmp/ca"
        ]
    }

    # pull down gato
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

bash generate_host.sh hcf-root "*.${openstack_networking_floatingip_v2.hcf-core-host-fip.address}.xip.io"

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
echo $DEVICE1 /data ext4 defaults 0 2 | sudo tee -a /etc/fstab
sudo mount /data
EOF
    }

    provisioner "remote-exec" {
        inline = <<EOF
set -e
sudo apt-get install -y wget
sudo apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo deb https://apt.dockerproject.org/repo ubuntu-trusty main | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get purge -y lxc-docker*
sudo apt-get install -y docker-engine=1.8.3-0~trusty
sudo usermod -aG docker ubuntu
# allow us to pull from the docker registry
# TODO: this needs to be removed when we publish to Docker Hub
echo DOCKER_OPTS=\"--insecure-registry ${var.registry_host} -s devicemapper\" | sudo tee -a /etc/default/docker
# We have to reboot since this switches our kernel.        
sudo reboot && sleep 10
EOF
    }

    #
    # gato
    #

    # pull down gato
    provisioner "file" {
        source = "scripts/gato"
        destination = "/tmp/gato"
    }

    provisioner "remote-exec" {
        inline = <<EOF
set -e
sudo mv /tmp/gato /usr/local/bin/gato
sudo chmod +x /usr/local/bin/gato
docker pull ${var.registry_host}/hcf/hcf-gato
/usr/local/bin/gato --version
EOF
    }

    #
    # HCF consul
    #

    # configure consul
    provisioner "remote-exec" {
        inline = [
        "sudo mkdir -p /opt/hcf/etc",
        "sudo mkdir -p /data/hcf-consul"
        ]
    }

    provisioner "file" {
        source = "scripts/consul.json"
        destination = "/tmp/consul.json"
    }

    # start the HCF consul server
    provisioner "remote-exec" {
        inline = [
        "sudo mv /tmp/consul.json /opt/hcf/etc/consul.json",
        "docker run -d -P --restart=always --net=host --name hcf-consul-server -v /opt/hcf/etc:/opt/hcf/etc -v /data/hcf-consul:/opt/hcf/share/consul -t ${var.registry_host}/hcf/consul-server:latest -bootstrap -client=0.0.0.0 --config-file /opt/hcf/etc/consul.json"
        ]
    }

    # populate HCF consul
    provisioner "file" {
        source = "scripts/consullin.bash"
        destination = "/tmp/consullin.bash"
    }

    provisioner "remote-exec" {
        inline = [
        "curl -L https://region-b.geo-1.objects.hpcloudsvc.com/v1/10990308817909/pelerinul/hcf.tar.gz -o /tmp/hcf-config-base.tgz",
        "bash /tmp/consullin.bash http://127.0.0.1:8501 /tmp/hcf-config-base.tgz"
        ]
    }

    provisioner "remote-exec" {
        inline = <<EOF
set -e        
curl -X PUT -d '"nats"' http://127.0.0.1:8501/v1/kv/hcf/user/nats/user
curl -X PUT -d '"goodpass"' http://127.0.0.1:8501/v1/kv/hcf/user/nats/password
curl -X PUT -d '"monit"' http://127.0.0.1:8501/v1/kv/hcf/user/hcf/monit/user
curl -X PUT -d '"monitpass"' http://127.0.0.1:8501/v1/kv/hcf/user/hcf/monit/password

# configure monit ports
curl -X PUT -d '{"name": "consul-monit", "address": "127.0.0.1", "port": 2830, "tags": ["monit"]}' http://127.0.0.1:8501/v1/agent/service/register
curl -X PUT -d '2830' http://127.0.0.1:8501/v1/kv/hcf/role/consul/hcf/monit/port
curl -X PUT -d '2831' http://127.0.0.1:8501/v1/kv/hcf/role/nats/hcf/monit/port
curl -X PUT -d '2832' http://127.0.0.1:8501/v1/kv/hcf/role/etcd/hcf/monit/port
curl -X PUT -d '2833' http://127.0.0.1:8501/v1/kv/hcf/role/stats/hcf/monit/port
curl -X PUT -d '2834' http://127.0.0.1:8501/v1/kv/hcf/role/ha_proxy/hcf/monit/port
curl -X PUT -d '2835' http://127.0.0.1:8501/v1/kv/hcf/role/nfs/hcf/monit/port
curl -X PUT -d '2836' http://127.0.0.1:8501/v1/kv/hcf/role/postgres/hcf/monit/port
curl -X PUT -d '2837' http://127.0.0.1:8501/v1/kv/hcf/role/uaa/hcf/monit/port
curl -X PUT -d '2838' http://127.0.0.1:8501/v1/kv/hcf/role/api/hcf/monit/port
curl -X PUT -d '2839' http://127.0.0.1:8501/v1/kv/hcf/role/clock_global/hcf/monit/port
curl -X PUT -d '2840' http://127.0.0.1:8501/v1/kv/hcf/role/api_worker/hcf/monit/port
curl -X PUT -d '2841' http://127.0.0.1:8501/v1/kv/hcf/role/hm9000/hcf/monit/port
curl -X PUT -d '2842' http://127.0.0.1:8501/v1/kv/hcf/role/doppler/hcf/monit/port
curl -X PUT -d '2843' http://127.0.0.1:8501/v1/kv/hcf/role/loggregator/hcf/monit/port
curl -X PUT -d '2844' http://127.0.0.1:8501/v1/kv/hcf/role/loggregator_trafficcontroller/hcf/monit/port
curl -X PUT -d '2845' http://127.0.0.1:8501/v1/kv/hcf/role/router/hcf/monit/port
curl -X PUT -d '2846' http://127.0.0.1:8501/v1/kv/hcf/role/runner/hcf/monit/port
curl -X PUT -d '2847' http://127.0.0.1:8501/v1/kv/hcf/role/acceptance_tests/hcf/monit/port
curl -X PUT -d '2848' http://127.0.0.1:8501/v1/kv/hcf/role/smoke_tests/hcf/monit/port
EOF
    }

    #
    # nats
    #

    # start the nats server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-nats -t ${var.registry_host}/hcf/cf-v${var.cf-release}-nats:latest http://127.0.0.1:8501"
        ]
    }

    # start the CF consul server
    provisioner "remote-exec" {
        inline = <<EOF
set -e
sudo mkdir -p /data/cf-consul

curl -X PUT -d 'false' http://127.0.0.1:8501/v1/kv/hcf/user/consul/require_ssl
curl -X PUT -d '["${openstack_compute_instance_v2.hcf-core-host.access_ip_v4}"]' http://127.0.0.1:8501/v1/kv/hcf/user/consul/agent/servers/lan
curl -X PUT -d '[]' http://127.0.0.1:8501/v1/kv/hcf/user/consul/encrypt_keys

curl -X PUT -d '"server"' http://127.0.0.1:8501/v1/kv/hcf/role/consul/consul/agent/mode
EOF
    }

    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-consul -v /data/cf-consul:/var/vcap/store -t ${var.registry_host}/hcf/cf-v${var.cf-release}-consul:latest http://127.0.0.1:8501"
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
        "docker run -d -P --restart=always --net=host --name cf-etcd -v /data/cf-etcd:/var/vcap/store -t ${var.registry_host}/hcf/cf-v${var.cf-release}-etcd:latest http://127.0.0.1:8501"
        ]
    }

    #
    # nfs
    #

    # start the nfs server
    provisioner "remote-exec" {
        inline = [
        "sudo mkdir -p /data/cf-nfs"
        ]
    }

    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-nfs -v /data/cf-nfs:/var/vcap/store -t ${var.registry_host}/hcf/cf-v${var.cf-release}-nfs:latest http://127.0.0.1:8501"
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
        "docker run -d -P --restart=always --net=host --name cf-postgres -v /data/cf-postgres:/var/vcap/store -t ${var.registry_host}/hcf/cf-v${var.cf-release}-postgres:latest http://127.0.0.1:8501"
        ]        
    }

    #
    # stats
    #

    # start the stats server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-stats -t ${var.registry_host}/hcf/cf-v${var.cf-release}-stats:latest http://127.0.0.1:8501"
        ]        
    }

    #
    # ha_proxy
    #

    # start the ha_proxy server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-ha_proxy -t ${var.registry_host}/hcf/cf-v${var.cf-release}-ha_proxy:latest http://127.0.0.1:8501"
        ]        
    }

    #
    # uaa
    #

    # start the uaa server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-uaa -t ${var.registry_host}/hcf/cf-v${var.cf-release}-uaa:latest http://127.0.0.1:8501"
        ]        
    }

    #
    # api
    #

    # start the api server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-api -t ${var.registry_host}/hcf/cf-v${var.cf-release}-api:latest http://127.0.0.1:8501"
        ]        
    }

    #
    # clock_global
    #

    # start the clock_global server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-clock_global -t ${var.registry_host}/hcf/cf-v${var.cf-release}-clock_global:latest http://127.0.0.1:8501"
        ]        
    }

    #
    # api_worker
    #

    # start the api_worker server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-api_worker -t ${var.registry_host}/hcf/cf-v${var.cf-release}-api_worker:latest http://127.0.0.1:8501"
        ]        
    }

    #
    # hm9000
    #

    # start the hm9000 server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-hm9000 -t ${var.registry_host}/hcf/cf-v${var.cf-release}-hm9000:latest http://127.0.0.1:8501"
        ]        
    }

    #
    # doppler
    #

    # start the doppler server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-doppler -t ${var.registry_host}/hcf/cf-v${var.cf-release}-doppler:latest http://127.0.0.1:8501"
        ]        
    }

    #
    # loggregator
    #

    # start the loggregator server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-loggregator -t ${var.registry_host}/hcf/cf-v${var.cf-release}-loggregator:latest http://127.0.0.1:8501"
        ]        
    }

    #
    # loggregator_trafficcontroller
    #

    # start the loggregator_trafficcontroller server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-loggregator_trafficcontroller -t ${var.registry_host}/hcf/cf-v${var.cf-release}-loggregator_trafficcontroller:latest http://127.0.0.1:8501"
        ]        
    }

    #
    # router
    #

    # start the router server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-router -t ${var.registry_host}/hcf/cf-v${var.cf-release}-router:latest http://127.0.0.1:8501"
        ]        
    }

    #
    # runner
    #

    # start the runner server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always --net=host --name cf-runner -t ${var.registry_host}/hcf/cf-v${var.cf-release}-runner:latest http://127.0.0.1:8501"
        ]        
    }
    
    provisioner "remote-exec" {
        inline = [
            "docker run -d -P --restart=always --net=host --name cf-stats -t ${var.registry_host}/hcf/cf-v${var.cf-release}-stats:latest http://127.0.0.1:8501"
        ]
    }
}

# commented out, will be restored shortly.

# resource "openstack_networking_floatingip_v2" "hcf-uaa-host-fip" {
#   pool = "${var.openstack_floating_ip_pool}"
# }

# resource "openstack_compute_instance_v2" "hcf-uaa-host" {
# 	depends_on = "openstack_compute_instance_v2.hcf-core-host"

#     name = "hcf_uaa"
#     flavor_id = "${var.openstack_flavor_id}"
#     image_id = "${var.openstack_base_image_id}"
#     key_pair = "${var.openstack_keypair}"
#     security_groups = [ "default", "hcf-container-host" ]
#     network = { uuid = "${var.openstack_network_id}" }

# 	floating_ip = "${openstack_networking_floatingip_v2.hcf-uaa-host-fip.address}"

#     connection {
#         host = "${openstack_networking_floatingip_v2.hcf-uaa-host-fip.address}"
#         user = "ubuntu"
#         key_file = "${var.key_file}"
#     }

#     provisioner "remote-exec" {
#         inline = [
#         "sudo apt-get install -y wget",
#         "wget -qO- https://get.docker.com/ | sh",
#         "sudo usermod -aG docker ubuntu",
#         # allow us to pull from the docker registry
#         # TODO: this needs to be removed when we publish to Docker Hub
#         "echo DOCKER_OPTS=\\\"--insecure-registry ${var.registry_host}\\\" | sudo tee -a /etc/default/docker",
#         # We have to reboot since this switches our kernel.        
#         "sudo reboot && sleep 10",
#         ]
#     }

#     # start the UAA server here
#     provisioner "remote-exec" {
#         inline = [
#         "docker ps"
#         ]
#     }
# }

# resource "openstack_networking_floatingip_v2" "hcf-dea-host-fip" {
#   pool = "${var.openstack_floating_ip_pool}"
#   count = "${var.dea_count}"
# }

# resource "openstack_compute_instance_v2" "hcf-dea-host" {
# 	depends_on = "openstack_compute_instance_v2.hcf-uaa-host"

#     name = "hcf_dea_${count.index}"
#     flavor_id = "${var.openstack_flavor_id}"
#     image_id = "${var.openstack_base_image_id}"
#     key_pair = "${var.openstack_keypair}"
#     security_groups = [ "default", "hcf-container-host" ]
#     network = { uuid = "${var.openstack_network_id}" }
#     count = "${var.dea_count}"

# 	floating_ip = "${element(openstack_networking_floatingip_v2.hcf-dea-host-fip.*.address,0)}"

#     connection {
#         host = "${element(openstack_networking_floatingip_v2.hcf-dea-host-fip.*.address,0)}"
#         user = "ubuntu"
#         key_file = "${var.key_file}"
#     }

#     provisioner "remote-exec" {
#         inline = [
#         "sudo apt-get install -y wget",
#         "wget -qO- https://get.docker.com/ | sh",
#         "sudo usermod -aG docker ubuntu",
#         # allow us to pull from the docker registry
#         # TODO: this needs to be removed when we publish to Docker Hub
#         "echo DOCKER_OPTS=\\\"--insecure-registry ${var.registry_host}\\\" | sudo tee -a /etc/default/docker",
#         # We have to reboot since this switches our kernel.        
#         "sudo reboot && sleep 10",
#         ]
#     }

#     # start the DEA server here
#     provisioner "remote-exec" {
#         inline = [
#         "docker ps"
#         ]
#     }
# }
