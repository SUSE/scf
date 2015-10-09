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

resource "openstack_compute_instance_v2" "hcf-core-host" {
    name = "hcf_core"
    flavor_id = "${var.openstack_flavor_id}"
    image_id = "${var.openstack_base_image_id}"
    key_pair = "${var.openstack_keypair}"
    security_groups = [ "default", "hcf-container-host" ]
    network = { uuid = "${var.openstack_network_id}" }

	floating_ip = "${openstack_networking_floatingip_v2.hcf-core-host-fip.address}"

    connection {
        host = "${openstack_networking_floatingip_v2.hcf-core-host-fip.address}"
        user = "ubuntu"
        key_file = "${var.key_file}"
    }

    provisioner "remote-exec" {
        inline = [
        "sudo apt-get install -y wget",
        "wget -qO- https://get.docker.com/ | sh",
        "sudo usermod -aG docker ubuntu",
        # allow us to pull from the docker registry
        # TODO: this needs to be removed when we publish to Docker Hub
        "echo DOCKER_OPTS=\\\"--insecure-registry ${var.registry_host}\\\" | sudo tee -a /etc/default/docker",
        # We have to reboot since this switches our kernel.        
        "sudo reboot && sleep 10",
        ]
    }

    # start the consul server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always -t ${var.registry_host}/hcf/consul-server:latest -bootstrap -client=0.0.0.0"
        ]
    }

    # start the gnatsd server
    provisioner "remote-exec" {
        inline = [
        "docker run -d -P --restart=always -t apcera/gnatsd"
        ]
    }
}

resource "openstack_networking_floatingip_v2" "hcf-uaa-host-fip" {
  pool = "${var.openstack_floating_ip_pool}"
}

resource "openstack_compute_instance_v2" "hcf-uaa-host" {
	depends_on = "openstack_compute_instance_v2.hcf-core-host"

    name = "hcf_uaa"
    flavor_id = "${var.openstack_flavor_id}"
    image_id = "${var.openstack_base_image_id}"
    key_pair = "${var.openstack_keypair}"
    security_groups = [ "default", "hcf-container-host" ]
    network = { uuid = "${var.openstack_network_id}" }

	floating_ip = "${openstack_networking_floatingip_v2.hcf-uaa-host-fip.address}"

    connection {
        host = "${openstack_networking_floatingip_v2.hcf-uaa-host-fip.address}"
        user = "ubuntu"
        key_file = "${var.key_file}"
    }

    provisioner "remote-exec" {
        inline = [
        "sudo apt-get install -y wget",
        "wget -qO- https://get.docker.com/ | sh",
        "sudo usermod -aG docker ubuntu",
        # allow us to pull from the docker registry
        # TODO: this needs to be removed when we publish to Docker Hub
        "echo DOCKER_OPTS=\\\"--insecure-registry ${var.registry_host}\\\" | sudo tee -a /etc/default/docker",
        # We have to reboot since this switches our kernel.        
        "sudo reboot && sleep 10",
        ]
    }

    # start the UAA server here
    provisioner "remote-exec" {
        inline = [
        "docker ps"
        ]
    }
}

resource "openstack_networking_floatingip_v2" "hcf-dea-host-fip" {
  pool = "${var.openstack_floating_ip_pool}"
  count = "${var.dea_count}"
}

resource "openstack_compute_instance_v2" "hcf-dea-host" {
	depends_on = "openstack_compute_instance_v2.hcf-uaa-host"

    name = "hcf_dea_${count.index}"
    flavor_id = "${var.openstack_flavor_id}"
    image_id = "${var.openstack_base_image_id}"
    key_pair = "${var.openstack_keypair}"
    security_groups = [ "default", "hcf-container-host" ]
    network = { uuid = "${var.openstack_network_id}" }
    count = "${var.dea_count}"

	floating_ip = "${element(openstack_networking_floatingip_v2.hcf-dea-host-fip.*.address,0)}"

    connection {
        host = "${element(openstack_networking_floatingip_v2.hcf-dea-host-fip.*.address,0)}"
        user = "ubuntu"
        key_file = "${var.key_file}"
    }

    provisioner "remote-exec" {
        inline = [
        "sudo apt-get install -y wget",
        "wget -qO- https://get.docker.com/ | sh",
        "sudo usermod -aG docker ubuntu",
        # allow us to pull from the docker registry
        # TODO: this needs to be removed when we publish to Docker Hub
        "echo DOCKER_OPTS=\\\"--insecure-registry ${var.registry_host}\\\" | sudo tee -a /etc/default/docker",
        # We have to reboot since this switches our kernel.        
        "sudo reboot && sleep 10",
        ]
    }

    # start the DEA server here
    provisioner "remote-exec" {
        inline = [
        "docker ps"
        ]
    }
}
