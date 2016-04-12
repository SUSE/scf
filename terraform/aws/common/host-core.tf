
resource "aws_instance" "core" {
    # Launch the instance after the internet gateway is up
    depends_on = [ "null_resource.core_requirements" ]

    # Launch the instance
    ami           = "${lookup(var.amazon_images, var.aws_region)}"
    instance_type = "${lookup(var.aws_instance_type, "ucloud")}"
    key_name      = "${aws_key_pair.admin.key_name}"

    # Give a name to the node
    tags {
        Name = "${var.cluster_prefix}-core"
    }

    # The VPC Subnet ID to launch in and security group
    subnet_id              = "${aws_subnet.public.id}"
    vpc_security_group_ids = [ "${null_resource.core_requirements.triggers.security_group}" ]

    # Create and attach the disks we need for data and docker device mapper.

    ebs_block_device {
        device_name = "${var.core_volume_device_data}"
        volume_size = "${var.core_volume_size_data}"
        # delete_on_termination : default => true
    }

    ebs_block_device {
        device_name = "${var.core_volume_device_mapper}"
        volume_size = "${var.core_volume_size_mapper}"
        # delete_on_termination : default => true
    }

    # Provision the node ...
    # - core_setup_prep
    # - core_setup_proxy
    # - core_setup_mangle
    # - core_setup_final
}
