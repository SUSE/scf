
resource "null_resource" "proxy_ip" {
    triggers = {
        private_ip = "${aws_spot_instance_request.proxy.private_ip}"
        public_ip  = "${aws_spot_instance_request.proxy.public_ip}"
    }
}
