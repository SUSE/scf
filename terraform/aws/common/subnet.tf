
# Add a public subnet into the VPC
resource "aws_subnet" "public" {
    vpc_id                  = "${aws_vpc.cluster.id}"
    cidr_block              = "10.0.1.0/24"
    map_public_ip_on_launch = true
    tags {
        Name = "${var.cluster_prefix}-subnet-public"
    }
}
