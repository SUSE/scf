
resource "null_resource" "core_setup_final" {
    depends_on = [ "null_resource.core_start_requirements" ]

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
	    "export    HCF_RUN_STORE=${var.runtime_store_directory}",
	    "mkdir -p $HCF_RUN_STORE",
	    "export    HCF_RUN_LOG_DIRECTORY=${var.runtime_log_directory}",
	    "mkdir -p $HCF_RUN_LOG_DIRECTORY",
            "bash -e ${var.fs_host_root}/opt/hcf/bin/run-all-roles.sh ${var.fs_host_root}/opt/hcf/etc"
        ]
    }
}
