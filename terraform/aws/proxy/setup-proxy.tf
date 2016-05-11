
resource "null_resource" "proxy_setup_final" {
    triggers = {
        core_ip = "${null_resource.proxy_ip.triggers.public_ip}"
    }

    connection {
        host = "${null_resource.proxy_ip.triggers.public_ip}"
        user = "ubuntu"
        private_key = "${file("${var.private_key_file}")}"
        # See aws_key_pair.admin for the public part
    }

    provisioner "local-exec" {
        command = "printf '\\033[0;32;1m ==> Starting proxy setup <== \\033[0m\\n'"
    }

    provisioner "local-exec" {
        # Wait for the proxy to come up without spamming the terminal with connection attempts
	command = "${path.module}/terraform/wait-for-ssh.sh ${null_resource.proxy_ip.triggers.public_ip} Proxy"
    }

    provisioner "remote-exec" {
        inline = [
            "echo 127.0.0.1 ip-$(echo ${null_resource.proxy_ip.triggers.private_ip} | tr . -) | sudo tee -a /etc/hosts"
        ]
    }

    provisioner "file" {
        source      = "${path.module}/terraform/proxy.conf"
        destination = "/tmp/proxy.conf"
    }

    provisioner "remote-exec" {
        inline = [ "printf '\\033[0;32m host reached \\033[0m\\n'" ]
    }

    provisioner "remote-exec" {
        script = "${path.module}/terraform/proxy-setup.sh"
    }
}
