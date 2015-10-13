# Based on RobR's cf-docker-registry.tf at 
# https://github.com/hpcloud/cf-docker-registry/blob/master/cf-docker-registry.tf

# minimum terraform script to create an instance on hpcloud and provision

variable "os_user" { }

variable "os_password" { }

variable "runtime_username" {
    default = "ubuntu" #TODO: User should be hcf
}

variable "key_file" { }

variable "key_pair" { }

provider "openstack" {

}

resource "openstack_networking_floatingip_v2" "nats-poc-fip" {
    pool = "Ext-Net"
}

resource "openstack_compute_instance_v2" "nats-poc" {
    name = "nats-poc"
    flavor_id = "102"
    key_pair = "${var.key_pair}"
    image_id = "564be9dd-5a06-4a26-ba50-9453f972e483"  #*
    # image name: "Ubuntu Server 14.04.1 LTS (amd64 20150706) - Partner Image"
    floating_ip = "${openstack_networking_floatingip_v2.nats-poc-fip.address}" #*
    network { 
         uuid = "f52350cd-6bb8-4869-858d-f76517a52d45"  #*
    } 

    connection {
          host = "${openstack_networking_floatingip_v2.nats-poc-fip.address}"
          user = "${var.runtime_username}"
          key_file = "${var.key_file}"
    }
    
    provisioner "remote-exec" {
        inline = [
            "sudo apt-get install -y wget",
    	    "wget -qO- https://get.docker.com | sh",
	    "sudo usermod -aG docker ubuntu",
	    # And we need to reboot before using docker : switch out the kernel"
	    "sudo reboot && sleep 10"
	]
    }
    provisioner "remote-exec" {
        inline = [
	    #TODO: Replace this line with a reference to the hcf docker registry
	    "docker pull morspin/nats",
	    "docker run -p 80:4222 -d morspin/nats"
        ]
    }
}
