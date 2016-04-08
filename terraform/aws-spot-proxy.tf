# # ## ###
## Section: Cloud API - Exported to user

# output "environment" {
#     value = "${null_resource.rm_configuration.triggers.rm_configuration}"
# }

output "floating_ip" {
    value = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}"
}

output "floating_domain" {
    value = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}.nip.io"
}

# # ## ###
## API into the generated declarations.
## - Definition of PUBLIC_IP, DOMAIN, *_PROXY, *_proxy (special variables)
## - Filesystem paths, local and remote

resource "null_resource" "PUBLIC_IP" {
    triggers = {
        PUBLIC_IP = "${aws_spot_instance_request.core.public_ip}"
    }
}

resource "null_resource" "DOMAIN" {
    triggers = {
        DOMAIN = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}.nip.io"
    }
}

resource "null_resource" "HTTP_PROXY" {
    triggers = {
        HTTP_PROXY = "http://${aws_spot_instance_request.proxy.private_ip}:3128/"
    }
}

resource "null_resource" "http_proxy" {
    triggers = {
        http_proxy = "http://${aws_spot_instance_request.proxy.private_ip}:3128/"
    }
}

resource "null_resource" "HTTPS_PROXY" {
    triggers = {
        HTTPS_PROXY = "http://${aws_spot_instance_request.proxy.private_ip}:3128/"
    }
}

resource "null_resource" "https_proxy" {
    triggers = {
        https_proxy = "http://${aws_spot_instance_request.proxy.private_ip}:3128/"
    }
}

resource "null_resource" "NO_PROXY" {
    triggers = {
        NO_PROXY = "${var.NO_PROXY}"
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

variable "public_key_file" {
	description = "Public key file for the AWS key pair to import"
}

variable "private_key_file" {
	description = "Private key file for the AWS key pair to import. Used to configure host connection"
}

variable "skip_ssl_validation" {
    default     = "false"
    description = "Skip SSL validation when interacting with AWS"
}

variable "cluster-prefix" {
    description = "Prefix prepended to all cluster resources (volumes, hostnames, security groups)"
    default     = "hcf"
}

variable aws_region {
    description = "The region to operate the ucloud from"
    default     = "us-west-2"
}

variable aws_instance_type {
    description = "AWS EC2 instance type for each node type"
    default = {
        "ucloud"       = "c4.xlarge" # spots /just for here, in case we have to increase
        "core"         = "t2.medium"
        "dea"          = "t2.medium"
        "dataservices" = "t2.medium"
        "controller"   = "t2.medium"
        "router"       = "t2.medium"
        "proxy"        = "c4.xlarge" # spots
    }
}

variable "amazon_images" {
    description = "Amazon AMIs of plain/vanilla Ubuntu 14.04 LTS ebs:hvm"
    # Note: t2.medium (see above) does not support AMIs using instance-store.
    # Note: t2.medium (see above) does not support AMIs using vir-type != HVM.
    # See
    #   https://cloud-images.ubuntu.com/locator/ec2/
    # for website to find such images
    default = {
        us-east-1      = "" # Northern Virginia
        us-west-2      = "ami-21b85141" # Oregon
        us-west-1      = "" # Northern California
        eu-west-1      = "" # Ireland
        eu-central-1   = "" # Frankfurt
        ap-southeast-1 = "" # Singapore
        ap-southeast-2 = "" # Sydney
        ap-northeast-1 = "" # Tokyo
        sa-east-1      = "" # Sao Paulo
    }
}

# # ## ###
## Section: Disk information: Sizes, Devices, ...

# Name of the device handling the disk/volume given to setup_blockstore.sh
# for formatting as ext4 and mounted in the VM under /data.

variable "core_volume_device_data" {
    default = "/dev/xvdf"
}

# Name of the device handling the disk/volume given to configure_docker.sh
# for use with LVM and the device-mapper storage-driver of docker.

variable "core_volume_device_mapper" {
    default = "/dev/xvdg"
}

variable "core_volume_size_data" {
    default = "40"
}

variable "core_volume_size_mapper" {
    default = "70"
}

# # ## ###
## Section: Locations for component state and log files.

#  Placed under /data, the directory the data volume is mounted at by
#  the "setup_blockstore_volume.sh" script.

variable "runtime_store_directory" {
    default = "/data/hcf/store"
}

variable "runtime_log_directory" {
    default = "/data/hcf/log"
}

# # ## ###
## Section: AWS ucloud

provider "aws" {
    region   = "${var.aws_region}"
    insecure = "${var.skip_ssl_validation}"
}

# # ## ###
## Section: ucloud network
#
# Setup a Virtual Private Cloud (VPC) for the cluster and expose the
# cluster endpoint to internet.
#
# Snarfed from our internal
#	stackato-cluster-tool/terraform/amazon-aws,
# written and maintained by Stefan Bourlon.
# Some changes (longer names, different names, indentation).

# Create the VPC
resource "aws_vpc" "cluster" {
    cidr_block = "10.0.0.0/16"
    tags {
        Name = "${var.cluster-prefix}-vpc"
    }
}

# Attach an internet gateway to the VPC
resource "aws_internet_gateway" "gateway" {
    depends_on = ["aws_vpc.cluster"]
    vpc_id     = "${aws_vpc.cluster.id}"
    tags {
        Name = "${var.cluster-prefix}-gateway"
    }
}

# Add a routing table entry to the internet gateway
resource "aws_route" "internet_gw" {
    depends_on             = ["aws_vpc.cluster"]
    route_table_id         = "${aws_vpc.cluster.main_route_table_id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = "${aws_internet_gateway.gateway.id}"
}

# Add a public subnet into the VPC
resource "aws_subnet" "public" {
    vpc_id                  = "${aws_vpc.cluster.id}"
    cidr_block              = "10.0.1.0/24"
    map_public_ip_on_launch = true
    availability_zone = "us-west-2c"
    tags {
        Name = "${var.cluster-prefix}-subnet-public"
    }
}

# Public subnet ACL
resource "aws_network_acl" "public" {
    tags {
        Name = "${var.cluster-prefix}-acl-public"
    }

    vpc_id     = "${aws_vpc.cluster.id}"
    subnet_ids = [ "${aws_subnet.public.id}" ]

    # No filtering at ACL level.
    # All filtering is done in the security groups later.

    # Allow inbound traffic on all ports from anywhere
    ingress {
        protocol   = "-1"
        rule_no    = 100
        action     = "allow"
        cidr_block = "0.0.0.0/0"
        from_port  = 0
        to_port    = 0
    }

    # Allow outbound traffic to all ports everywhere
    egress {
        protocol   = "-1"
        rule_no    = 100
        action     = "allow"
        cidr_block = "0.0.0.0/0"
        from_port  = 0
        to_port    = 0
    }
}

# # ## ###
## Section: Proxy

resource "aws_spot_instance_request" "proxy" {
    spot_price = "0.232"
    spot_type = "one-time"
    wait_for_fulfillment = true
    availability_zone = "us-west-2c"

    # Launch the instance after the internet gateway is up
    depends_on = [
        "aws_internet_gateway.gateway",
    ]

    # Launch the instance
    ami           = "${lookup(var.amazon_images, var.aws_region)}"
    instance_type = "${lookup(var.aws_instance_type, "proxy")}"
    key_name      = "${aws_key_pair.admin.key_name}"

    # Give a name to the node
    tags {
        Name = "${var.cluster-prefix}-proxy"
    }

    # The VPC Subnet ID to launch in and security group
    subnet_id              = "${aws_subnet.public.id}"
    vpc_security_group_ids = [ "${aws_security_group.frontend.id}" ]

    # Provision the node

    connection {
        user = "ubuntu"
        private_key = "${file("${var.private_key_file}")}"
        # See key_name above, and aws_key_pair.admin for the public
        # part
    }

    provisioner "local-exec" {
        command = "printf '\\033[0;32;1m ==> Starting proxy setup <== \\033[0m\\n'"
    }

    provisioner "local-exec" {
        # Wait for the proxy to come up without spamming the terminal with connection attempts
        command = "for i in `seq 10`; do nc ${aws_spot_instance_request.proxy.public_ip} 22 </dev/null && exit 0; sleep 10; done ; exit 1"
    }

    provisioner "remote-exec" {
        inline = [
            "echo 127.0.0.1 ip-$(echo ${self.private_ip} | tr . -) | sudo tee -a /etc/hosts"
        ]
    }

    provisioner "file" {
        source = "${path.module}/terraform/proxy.conf"
        destination = "/tmp/proxy.conf"
    }

    provisioner "remote-exec" {
        inline = [ "printf '\\033[0;32m host reached \\033[0m\\n'" ]
    }

    provisioner "remote-exec" {
        script = "${path.module}/terraform/proxy-setup.sh"
    }
}

# # ## ###
## Section: ucloud compute

resource "aws_key_pair" "admin" {
  key_name   = "${var.cluster-prefix}-admin-key"
  public_key = "${file("${var.public_key_file}")}"
}

resource "aws_spot_instance_request" "core" {
    spot_price = "0.232"
    spot_type = "one-time"
    wait_for_fulfillment = true
    availability_zone = "us-west-2c"

    # Launch the instance after the internet gateway is up
    depends_on = [ "aws_spot_instance_request.proxy" ]

    # Launch the instance
    ami           = "${lookup(var.amazon_images, var.aws_region)}"
    instance_type = "${lookup(var.aws_instance_type, "ucloud")}"
    key_name      = "${aws_key_pair.admin.key_name}"

    # Give a name to the node
    tags {
        Name = "${var.cluster-prefix}-core"
    }

    # The VPC Subnet ID to launch in and security group
    subnet_id              = "${aws_subnet.public.id}"
    vpc_security_group_ids = [ "${aws_security_group.backend.id}" ]

    # Create and attach the disks we need for data and docker device mapper.

    ebs_block_device {
        device_name = "${var.core_volume_device_data}"
        volume_size = "${var.core_volume_size_data}"
        # delete_on_termination : default => true
    }

    ebs_block_device {
        device_name = "${var.core_volume_device_mapper}"
        volume_size = "${var.core_volume_size_mapper}"
        # delete_on_termination : default => true
    }

    # Provision the node

    connection {
        user = "ubuntu"
        private_key = "${file("${var.private_key_file}")}"
        # See key_name above, and aws_key_pair.admin for the public
        # part
    }

    provisioner "local-exec" {
        command = "echo ___ BEGIN SETUP ________________________________________________________"
    }
    provisioner "remote-exec" {
        inline = [ "echo ___ HOST REACHED ________" ]
    }

    # (1) Install scripts and binaries. Recursive. Replaces all separate uploads.
    provisioner "file" {
        source = "${path.module}/${var.fs_local_root}"
        destination = "${var.fs_host_root}"
    }

    # (1a) Quick inspection of the environment we found ourselves in.
    provisioner "remote-exec" {
        inline = [
            "echo ___ ENVIRONMENT __________",
	    "env",
	    "echo ___ CURRENT DIRECTORY ____",
	    "pwd",
            # "echo ___ CWD CONTENT __________",
	    # "ls -laFR",
            # "echo ___ FILESYSTEMS __________",
	    # "df -h",
            "echo ___ DEVICES ______________",
	    "bash -e ${var.fs_host_root}/opt/hcf/bin/show_attached_disks.sh xvd",
            "echo ___ BEGIN INTERNAL SETUP _"
        ]
    }

    provisioner "remote-exec" {
        inline = [
            "echo 127.0.0.1 ip-$(echo ${self.private_ip} | tr . -) | sudo tee -a /etc/hosts",
            # The fix above prevents sudo from moaning about its inability to resolve the hostname.
            # We see it of course moaning once, in the sudo above. Afterward it should not anymore.
            # Terraform, or the image it uses apparently sets the chosen name (based on the private ip)
            # only into /etc/hostname. The mismatch with /etc/hosts then causes the messages.
            # Ref: http://askubuntu.com/questions/59458/error-message-when-i-run-sudo-unable-to-resolve-host-none

            # Fix sudo reading /etc/environment; see https://bugs.launchpad.net/ubuntu/+source/sudo/+bug/1301557
            "sudo perl -p -i -e 's@^auth(.*pam_env.so)@session$${1}@' /etc/pam.d/sudo"
        ]
    }

    provisioner "remote-exec" {
        inline = [
            # Set up proxies
            "echo 'http_proxy=${null_resource.HTTP_PROXY.triggers.HTTP_PROXY}' | sudo tee -a /etc/environment",
            "echo 'HTTP_PROXY=${null_resource.HTTP_PROXY.triggers.HTTP_PROXY}' | sudo tee -a /etc/environment",
            "echo 'https_proxy=${null_resource.HTTPS_PROXY.triggers.HTTPS_PROXY}' | sudo tee -a /etc/environment",
            "echo 'HTTPS_PROXY=${null_resource.HTTPS_PROXY.triggers.HTTPS_PROXY}' | sudo tee -a /etc/environment",
            "echo 'Acquire::http::Proxy \"${null_resource.HTTP_PROXY.triggers.HTTP_PROXY}\";' | sudo tee -a /etc/apt/apt.conf.d/60-proxy",
            "echo 'Acquire::https::Proxy \"${null_resource.HTTPS_PROXY.triggers.HTTPS_PROXY}\";' | sudo tee -a /etc/apt/apt.conf.d/60-proxy",
            "echo 'NO_PROXY=${var.NO_PROXY}' | sudo tee -a /etc/environment",
            "echo 'no_proxy=${var.NO_PROXY}' | sudo tee -a /etc/environment",
        ]
    }

    # Ensure we pick up the changes to /etc/environment before running the rest

    provisioner "remote-exec" {
        inline = [
            "set -e",
            "sudo chmod -R ug+x ${var.fs_host_root}/opt/hcf/bin/*",

            # Format and mount the /data volume

	    "bash -e ${var.fs_host_root}/opt/hcf/bin/setup_blockstore_volume.sh ${var.core_volume_device_data}",
	    "sudo chown -R ubuntu:ubuntu /data",

            # Install and configure docker in the VM, including pulling the hcf images
            # This also makes the device-mapper volume available

	    "bash -e ${var.fs_host_root}/opt/hcf/bin/docker/install_kernel.sh"
        ]
    }

    # install_kernel ends in a reboot of the instance. We must use a
    # second provisioner (see below) to prevent TF from stopping the
    # entire process and continue with the remainder.

    provisioner "remote-exec" {
        inline = [
            "set -e",
            "echo ___ Installing docker ___________________",
            "sudo bash -e ${var.fs_host_root}/opt/hcf/bin/docker/install_docker.sh ubuntu",

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

            # See "core_final_setup" below for the remaining
            # provisioning we have to do (insert the configuration and
            # start all the roles).

            # The separate resource is needed to break a cycle on the
            # instance's public ip. Available only after the instance
            # is up it is used in the null_resources "PUBLIC_IP",
            # "DOMAIN" and the generated "rm_configuration" (RMC).

            # That makes use of RMC here in the instance itself a
            # cycle TF cannot handle.
        ]
    }
}

resource "null_resource" "core_final_setup" {
    # Wait for the hairpin egress to be available before starting
    depends_on = [ "aws_security_group_rule.backend_egress_hairpin" ]

    triggers = {
        core_ip = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}"
    }

    # Using the public_ip of the core instance in the rm_configuration
    # used in the provision of the core instance causes a dependency
    # cycle TF will bail out on.

    # The chosen fix is to move the provisioning code inducing the
    # that cycle into a separate resource, this one here, to be run
    # after the core instance is up and mostly running, on the core
    # instance. This breaks the cycle.

    connection {
        host = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}"
        user = "ubuntu"
        private_key = "${file("${var.private_key_file}")}"
        # See aws_key_pair.admin for the public part
    }

    provisioner "remote-exec" {
        inline = [
            # Put the RM config settings into the host

            "echo ___ Save RM settings ____________________",
            "mkdir -p ${var.fs_host_root}/opt/hcf/etc/",
            "echo '${null_resource.rm_configuration.triggers.rm_configuration}' > ${var.fs_host_root}/opt/hcf/etc/dev-settings.env",

            # (25) Run the jobs
            "echo ___ Start the jobs ______________________",
            "bash -e ${var.fs_host_root}/opt/hcf/bin/run-all-roles.sh ${var.fs_host_root}/opt/hcf/etc"
        ]
    }
}
