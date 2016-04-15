
resource "null_resource" "core_private_ip" {
    triggers = {
        private_ip = "${aws_instance.core.private_ip}"
    }
}

resource "null_resource" "PUBLIC_IP" {
    triggers = {
        PUBLIC_IP = "${aws_instance.core.public_ip}"
    }
}
