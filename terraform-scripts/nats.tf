# Based on RobR's cf-docker-registry.tf at 
# https://github.com/hpcloud/cf-docker-registry/blob/master/cf-docker-registry.tf

variable "os_user" {
    description = "${var.hpcloud_username}"
}

variable "os_password" {
    description = "${var.hpcloud_password}"
}

variable "key_file" {
    description = "Private key file for connecting to new host"
}

provider "openstack" {

}

resource "openstack_compute_secgroup_v2" "cf-docker-registry-sg" {
    name = "cf-docker-registry-sg"
    description = "Docker Registry"
    rule {
        from_port = 5000
        to_port = 5000
        ip_protocol = "tcp"
        cidr = "0.0.0.0/0"
    }
}

resource "openstack_objectstorage_container_v1" "cf-docker-registry-container" {
  name = "cf-docker-registry"

  lifecycle {
    # Do not destroy this container during a destroy. That would be disastrous.
    create_only = true
  }
}

resource "openstack_networking_floatingip_v2" "cf-docker-registry-fip" {
  pool = "Ext-Net"
}

resource "openstack_compute_instance_v2" "cf-docker-registry" {
    name = "cf-docker-registry"
    flavor_id = "102"
    image_id = "564be9dd-5a06-4a26-ba50-9453f972e483"
    key_pair = "colin-apaas"
    security_groups = [ "default", "cf-docker-registry-sg" ]
    floating_ip = "${openstack_networking_floatingip_v2.cf-docker-registry-fip.address}"
    network { 
        uuid = "f52350cd-6bb8-4869-858d-f76517a52d45" 
    } 

    connection {
        host = "${openstack_networking_floatingip_v2.cf-docker-registry-fip.address}"
        user = "ubuntu"
        key_file = "${var.key_file}"
    }

    provisioner "remote-exec" {
        inline = [
        "mkdir -p /home/ubuntu/scripts",
        "mkdir -p /home/ubuntu/config"
        ]
    }

    # Copies the scripts to /home/ubuntu/scripts
    provisioner "file" {
        source = "scripts/"
        destination = "/home/ubuntu/scripts"
    }

    provisioner "file" {
        source = "config/"
        destination = "/home/ubuntu/config"
    }

    provisioner "remote-exec" {
        inline = [
        "bash /home/ubuntu/scripts/00-docker.sh",
        "sudo usermod -aG docker ubuntu",
        # We have to reboot since this switches our kernel.
        "sudo reboot && sleep 10",
        ]
    }

    # This is a separate provisioner - this is because Terraform seems to
    # skip the rest of the commands when you reboot the host. This will cause
    # a new SSH connection to be created.
    provisioner "remote-exec" {
        inline = [
        # Now that we've rebooted, we can start the registry.
        "docker run -d -p 5000:5000 -e 'REGISTRY_STORAGE_SWIFT_USERNAME=${var.os_user}' -e 'REGISTRY_STORAGE_SWIFT_PASSWORD=${var.os_password}' --restart=always --name registry -v /home/ubuntu/config/config.yml:/etc/docker/registry/config.yml registry:2",
        "docker ps"
        ]
    }
}
