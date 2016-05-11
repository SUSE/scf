
resource "null_resource" "core_private_ip" {
    triggers = {
        private_ip = "${aws_spot_instance_request.core.private_ip}"
    }
}

resource "null_resource" "PUBLIC_IP" {
    triggers = {
        PUBLIC_IP = "${aws_spot_instance_request.core.public_ip}"
    }
}
