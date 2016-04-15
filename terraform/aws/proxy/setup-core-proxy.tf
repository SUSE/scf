# # ## ###
## Section: Core provisioner: Proxy setup in core

resource "null_resource" "core_setup_proxy" {
    depends_on = [ "null_resource.core_setup_prep",
                   "null_resource.proxy_setup_final" ]

    triggers = {
        core_ip = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}"
    }

    connection {
        host = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}"
        user = "ubuntu"
        private_key = "${file("${var.private_key_file}")}"
        # See aws_key_pair.admin for the public part
    }

    provisioner "remote-exec" {
        inline = [
            "set -e",
            # Set up proxies
            "echo 'http_proxy=${null_resource.HTTP_PROXY.triggers.HTTP_PROXY}' | sudo tee -a /etc/environment",
            "echo 'HTTP_PROXY=${null_resource.HTTP_PROXY.triggers.HTTP_PROXY}' | sudo tee -a /etc/environment",
            "echo 'https_proxy=${null_resource.HTTPS_PROXY.triggers.HTTPS_PROXY}' | sudo tee -a /etc/environment",
            "echo 'HTTPS_PROXY=${null_resource.HTTPS_PROXY.triggers.HTTPS_PROXY}' | sudo tee -a /etc/environment",
            "echo 'Acquire::http::Proxy \"${null_resource.HTTP_PROXY.triggers.HTTP_PROXY}\";' | sudo tee -a /etc/apt/apt.conf.d/60-proxy",
            "echo 'Acquire::https::Proxy \"${null_resource.HTTPS_PROXY.triggers.HTTPS_PROXY}\";' | sudo tee -a /etc/apt/apt.conf.d/60-proxy",
            "echo 'NO_PROXY=${var.NO_PROXY}' | sudo tee -a /etc/environment",
            "echo 'no_proxy=${var.NO_PROXY}' | sudo tee -a /etc/environment",

            # Wait for the proxy to come up without spamming the terminal with connection attempts
            "bash -e ${var.fs_host_root}/opt/hcf/bin/tools/wait-for-http.sh ${null_resource.HTTP_PROXY.triggers.HTTP_PROXY} Proxy"
        ]
    }
}
