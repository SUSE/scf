
resource "null_resource" "proxy_ip" {
    triggers = {
        private_ip = "${aws_instance.proxy.private_ip}"
        public_ip  = "${aws_instance.proxy.public_ip}"
    }
}
