# # ## ###
## Core requirements, un-proxied configuration.

resource "null_resource" "core_requirements" {
    # Launch core after the internet gateway is up
    depends_on = [ "aws_internet_gateway.gateway", "aws_vpc.cluster", "aws_subnet.public" ]

    triggers = {
        security_group = "${aws_security_group.frontend.id}"
    }
}

resource "null_resource" "core_start_requirements" {
    depends_on = [ "null_resource.core_setup_mangle" ]

    triggers = {
        dummy = "dummy"
    }
}
