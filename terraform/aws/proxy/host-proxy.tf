# # ## ###
## Section: Proxy

resource "aws_instance" "proxy" {
    # Launch the instance after the internet gateway is up
    depends_on = [
        "aws_internet_gateway.gateway",
    ]

    # Launch the instance
    ami           = "${lookup(var.amazon_images, var.aws_region)}"
    instance_type = "${lookup(var.aws_instance_type, "proxy")}"
    key_name      = "${aws_key_pair.admin.key_name}"

    # Give a name to the node
    tags {
        Name = "${var.cluster_prefix}-proxy"
    }

    # The VPC Subnet ID to launch in and security group
    subnet_id              = "${aws_subnet.public.id}"
    vpc_security_group_ids = [ "${aws_security_group.frontend.id}" ]

    # Provision the node ... See null_resource.proxy_setup_final
}
