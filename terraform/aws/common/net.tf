
# # ## ###
## Section: ucloud network
#
# Setup a Virtual Private Cloud (VPC) for the cluster and expose the
# cluster endpoint to internet.
#
# Snarfed from our internal
#	stackato-cluster-tool/terraform/amazon-aws,
# written and maintained by Stefan Bourlon.
# Some changes (longer names, different names, indentation).

resource "null_resource" "DOMAIN" {
    triggers = {
        DOMAIN = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}.nip.io"
    }
}

# Create the VPC
resource "aws_vpc" "cluster" {
    cidr_block = "10.0.0.0/16"
    tags {
        Name = "${var.cluster_prefix}-vpc"
    }
}

# Attach an internet gateway to the VPC
resource "aws_internet_gateway" "gateway" {
    depends_on = ["aws_vpc.cluster"]
    vpc_id     = "${aws_vpc.cluster.id}"
    tags {
        Name = "${var.cluster_prefix}-gateway"
    }
}

# Add a routing table entry to the internet gateway
resource "aws_route" "internet_gw" {
    depends_on             = ["aws_vpc.cluster"]
    route_table_id         = "${aws_vpc.cluster.main_route_table_id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = "${aws_internet_gateway.gateway.id}"
}

# Public subnet ACL
resource "aws_network_acl" "public" {
    tags {
        Name = "${var.cluster_prefix}-acl-public"
    }

    vpc_id     = "${aws_vpc.cluster.id}"
    subnet_ids = [ "${aws_subnet.public.id}" ]

    # No filtering at ACL level.
    # All filtering is done in the security groups later.

    # Allow inbound traffic on all ports from anywhere
    ingress {
        protocol   = "-1"
        rule_no    = 100
        action     = "allow"
        cidr_block = "0.0.0.0/0"
        from_port  = 0
        to_port    = 0
    }

    # Allow outbound traffic to all ports everywhere
    egress {
        protocol   = "-1"
        rule_no    = 100
        action     = "allow"
        cidr_block = "0.0.0.0/0"
        from_port  = 0
        to_port    = 0
    }
}
