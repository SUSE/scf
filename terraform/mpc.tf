# # ## ###
## Section: Cloud API - Exported to user

output "environment" {
    value = "${null_resource.rm_configuration.triggers.rm_configuration}"
}

output "floating_ip" {
    value = "${openstack_networking_floatingip_v2.hcf-core-host-fip.address}"
}

output "floating_domain" {
    value = "${openstack_networking_floatingip_v2.hcf-core-host-fip.address}.nip.io"
}

# # ## ###
## API into the generated declarations.
## - Definition of PUBLIC_IP (special variable)
## - Definition of DOMAIN (special variable)
## - Filesystem paths, local and remote

resource "null_resource" "PUBLIC_IP" {
    triggers = {
        PUBLIC_IP = "${openstack_networking_floatingip_v2.hcf-core-host-fip.address}"
    }
}

resource "null_resource" "DOMAIN" {
    triggers = {
        DOMAIN = "${openstack_networking_floatingip_v2.hcf-core-host-fip.address}.nip.io"
    }
}

variable "fs_local_root" {
    default = "./container-host-files/"
}

variable "fs_host_root" {
    default = "/home/ubuntu"
}

# # ## ###
## Section: ucloud core variables

variable "skip_ssl_validation" {
    default = "false"
    description = "Skip SSL validation when interacting with OpenStack"
}

variable "cluster-prefix" {
	description = "Prefix prepended to all cluster resources (volumes, hostnames, security groups)"
	default = "hcf"
}

variable "key_file" {
	description = "Private key file for newly created hosts"
}

# Name of the device handling the disk/volume given to setup_blockstore.sh
# for formatting as ext4 and mounted in the VM under /data.

# ATTENTION !! DANGER !! The devices are assigned in the order of volumes
## attached in the compute-instance, starting from b on up. Changing the order
## requires updates here too. The system does not seem to use our device
## assignments over the default/automatic assignment, so this here simply
## tries to match the automatic one.

variable "core_volume_device_data" {
	default = "/dev/vdb"
}

# Name of the device handling the disk/volume given to configure_docker.sh
# for use with LVM and the device-mapper storage-driver of docker.

variable "core_volume_device_mapper" {
	default = "/dev/vdc"
}

# HOS/MPC requires a networkd id, and that is also sufficient.
#         We cannot specify (just) by name :(

variable "openstack_network_id" {}

variable "openstack_keypair" {}

variable "openstack_availability_zone" {
	default = "nova"
}

variable "openstack_region" {
	default = "region1"
}

variable "openstack_flavor_name" {
	default = {
		core = "m1.small"
		dea  = "m1.small"
		test = "m1.small"
	}
}

variable "openstack_base_image_name" {
	default = "Ubuntu 14.04"
}

variable "openstack_floating_ip_pool" {
	default = "ext-net"
}

variable "dns_server" {
	default = "8.8.8.8"
}

variable "core_volume_size_data" {
	default = "70"
	# We need only 40, but this way the two disks are
	# interchangeable, defeating the race-condition switching
	# their /dev/vd assignments. Consider it a band-aid until
	# either TF openstack provider honors device assignments, or
	# we can determine the actual assignment from a provisioner.
}

variable "core_volume_size_mapper" {
	default = "70"
}

# Locations for component state and log files.
# Placed under /data, the directory the data volume is mounted at by
# the "setup_blockstore_volume.sh" script.

variable "runtime_store_directory" {
	default="/data/hcf/store"
}

variable "runtime_log_directory" {
	default="/data/hcf/log"
}

# # ## ###
## Section: ucloud core machine specification

provider "openstack" {
    insecure = "${var.skip_ssl_validation}"
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
        from_port = 2222
        to_port = 2222
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

# Disk/Volume for /data, see setup_blockstore.sh

resource "openstack_blockstorage_volume_v1" "hcf-core-vol-data" {
  name = "${var.cluster-prefix}-core-vol-data"
  description = "Helion Cloud Foundry Core Data"
  size = "${var.core_volume_size_data}"
  availability_zone = "nova" ## "${var.openstack_availability_zone}"
}

# Disk/Volume for docker device-mapper, see configure_docker.sh

resource "openstack_blockstorage_volume_v1" "hcf-core-vol-mapper" {
  name = "${var.cluster-prefix}-core-vol-mapper"
  description = "Helion Cloud Foundry Core Mapper"
  size = "${var.core_volume_size_mapper}"
  availability_zone = "nova" ## "${var.openstack_availability_zone}"
}

resource "openstack_compute_instance_v2" "hcf-core-host" {
    name        = "${var.cluster-prefix}-core"
    flavor_name = "${var.openstack_flavor_name.core}"
    image_name  = "${var.openstack_base_image_name}"
    key_pair    = "${var.openstack_keypair}"

    security_groups = [ "default", "${openstack_compute_secgroup_v2.hcf-container-host-secgroup.id}" ]

    network = {
	uuid = "${var.openstack_network_id}"
    }
    availability_zone = "${var.openstack_availability_zone}"

    floating_ip = "${openstack_networking_floatingip_v2.hcf-core-host-fip.address}"

    # ATTENTION !! DANGER !! The devices are assigned in the order of volumes
    ## attached here, starting from b on up. Changing the order here requires
    ## updates to the core_volume_device_* variables. Our assignments below
    ## seem to be ignored in favor of automatic ones, so opur assignments are
    ## changed to match :(

    # /data volume - see setup_blockstore.sh
    volume = {
        volume_id = "${openstack_blockstorage_volume_v1.hcf-core-vol-data.id}"
        device    = "${var.core_volume_device_data}"
    }

    # docker device mapper volume - see configure_docker.sh
    volume = {
        volume_id = "${openstack_blockstorage_volume_v1.hcf-core-vol-mapper.id}"
        device    = "${var.core_volume_device_mapper}"
    }

    connection {
        host = "${openstack_networking_floatingip_v2.hcf-core-host-fip.address}"
        user = "ubuntu"
        key_file = "${var.key_file}"
    }

    # (1) Install scripts and binaries. Recursive. Replaces all separate uploads.
    provisioner "file" {
        source = "${path.module}/${var.fs_local_root}"
        destination = "${var.fs_host_root}"
    }

    provisioner "remote-exec" {
        inline = [
            "echo 127.0.0.1 ${var.cluster-prefix}-core | sudo tee -a /etc/hosts",
            # The fix above prevents sudo from moaning about its inability to resolve the hostname.
            # We see it of course moaning once, in the sudo above. Afterward it should not anymore.
            # Terraform, or the image it uses apparently sets the name only into /etc/hostname.
            # The mismatch with /etc/hosts then causes the messages.
            # Ref: http://askubuntu.com/questions/59458/error-message-when-i-run-sudo-unable-to-resolve-host-none

            "sudo chmod -R ug+x ${var.fs_host_root}/opt/hcf/bin/*",

            # Format and mount the /data volume

	    "bash -e ${var.fs_host_root}/opt/hcf/bin/setup_blockstore_volume.sh ${var.core_volume_device_data}",
	    "sudo chown -R ubuntu:ubuntu /data",

            # Install and configure docker in the VM, including pulling the hcf images
            # This also makes the device-mapper volume available

	    "bash -e ${var.fs_host_root}/opt/hcf/bin/docker/install_kernel.sh",
        ]
    }

    # install_kernel ends in a reboot of the instance. We must use a
    # second provisioner (see below) to prevent TF from stopping the
    # entire process and continue with the remainder.

    provisioner "remote-exec" {
        inline = [
	    "echo ___ Installing docker ___________________",
	    "bash -e ${var.fs_host_root}/opt/hcf/bin/docker/install_docker.sh ubuntu",

	    "echo ___ Configuring docker __________________",
	    "sudo bash -e ${var.fs_host_root}/opt/hcf/bin/docker/configure_docker.sh ${var.core_volume_device_mapper} 64 4",
        ]
    }

    # install_docker added the docker group to the (ubuntu)
    # user. Splitting the provisioner generates a new shell where this
    # change is active.

    provisioner "remote-exec" {
        inline = [
            "echo ___ Setting up docker network ___________",
            "bash -e ${var.fs_host_root}/opt/hcf/bin/docker/setup_network.sh 172.20.10.0/24 172.20.10.1",

            "echo ___ Install y2j support ______________",
            "bash -e ${var.fs_host_root}/opt/hcf/bin/tools/install_y2j.sh",

            "echo ___ Logging into Docker Trusted Registry for image pulls",
            "docker login '-e=${var.docker_email}' '-u=${var.docker_username}' '-p=${var.docker_password}' ${var.docker_trusted_registry}",

            "echo ___ Pull docker images __________________",
            "${null_resource.docker_loader.triggers.docker_loader}",

            # Put the RM config settings into the host

            "echo ___ Save RM settings ____________________",
            "mkdir -p ${var.fs_host_root}/opt/hcf/etc/",
            "echo '${null_resource.rm_configuration.triggers.rm_configuration}' > ${var.fs_host_root}/opt/hcf/etc/dev-settings.env",

            # (25) Run the jobs

            "echo ___ Start the jobs ______________________",
            "${null_resource.runner_tasks_pre_flight.triggers.runner_tasks_pre_flight}"
            "${null_resource.runner_jobs.triggers.runner_jobs}"
            "${null_resource.runner_tasks_post_flight.triggers.runner_tasks_post_flight}"
        ]
    }
}
