
resource "null_resource" "core_setup_prep" {
    # Indirect dependency on "core" compute host
    triggers = {
        core_ip = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}"
    }

    connection {
        host = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}"
        user = "ubuntu"
        private_key = "${file("${var.private_key_file}")}"
        # See aws_key_pair.admin for the public part
    }

    provisioner "local-exec" {
        command = "echo ___ BEGIN SETUP ________________________________________________________"
    }

    provisioner "local-exec" {
        # Wait for the core to come up without spamming the terminal with connection attempts
	command = "${path.module}/terraform/wait-for-ssh.sh ${null_resource.PUBLIC_IP.triggers.PUBLIC_IP} Core"
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
            "echo 127.0.0.1 ip-$(echo ${null_resource.core_private_ip.triggers.private_ip} | tr . -) | sudo tee -a /etc/hosts",
            # The fix above prevents sudo from moaning about its inability to resolve the hostname.
            # We see it of course moaning once, in the sudo above. Afterward it should not anymore.
            # Terraform, or the image it uses apparently sets the chosen name (based on the private ip)
            # only into /etc/hostname. The mismatch with /etc/hosts then causes the messages.
            # Ref: http://askubuntu.com/questions/59458/error-message-when-i-run-sudo-unable-to-resolve-host-none

            # Fix sudo reading /etc/environment; see https://bugs.launchpad.net/ubuntu/+source/sudo/+bug/1301557
            "sudo perl -p -i -e 's@^auth(.*pam_env.so)@session$${1}@' /etc/pam.d/sudo"
        ]
    }
}
