
resource "null_resource" "core_setup_mangle" {
    depends_on = [ "null_resource.core_setup_proxy" ]

    triggers = {
        core_ip = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}"
    }

    connection {
        host = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}"
        user = "ubuntu"
        private_key = "${file("${var.private_key_file}")}"
        # See aws_key_pair.admin for the public part
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

    provisioner "local-exec" {
        # Wait for the core to come up without spamming the terminal with connection attempts
	command = "${path.module}/terraform/wait-for-ssh.sh ${null_resource.PUBLIC_IP.triggers.PUBLIC_IP} Core"
    }

    provisioner "remote-exec" {
        inline = [
            "set -e",
            "echo ___ Installing docker ___________________",
            "sudo bash -e ${var.fs_host_root}/opt/hcf/bin/docker/install_docker.sh ubuntu",

            "echo ___ Configuring docker __________________",
            "sudo bash -e ${var.fs_host_root}/opt/hcf/bin/docker/configure_docker.sh ${var.core_volume_device_mapper} ${var.core_volume_size_mapper}",
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

            # See "core_setup_mangle" below for the remaining
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
