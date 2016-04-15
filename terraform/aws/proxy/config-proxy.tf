# Note, all four variables exist in the role manifest, forcing their definition.

resource "null_resource" "HTTP_PROXY" {
    triggers = {
        HTTP_PROXY = "${null_resource.THE_PROXY.triggers.THE_PROXY}"
    }
}

resource "null_resource" "http_proxy" {
    triggers = {
        http_proxy = "${null_resource.THE_PROXY.triggers.THE_PROXY}"
    }
}

resource "null_resource" "HTTPS_PROXY" {
    triggers = {
        HTTPS_PROXY = "${null_resource.THE_PROXY.triggers.THE_PROXY}"
    }
}

resource "null_resource" "https_proxy" {
    triggers = {
        https_proxy = "${null_resource.THE_PROXY.triggers.THE_PROXY}"
    }
}

resource "null_resource" "NO_PROXY" {
    triggers = {
        NO_PROXY = "${var.NO_PROXY}"
    }
}

resource "null_resource" "THE_PROXY" {
    triggers = {
	THE_PROXY = "http://${null_resource.proxy_ip.triggers.private_ip}:3128/"
    }
}
