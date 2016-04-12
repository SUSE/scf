# # ## ###
## Core requirements, proxied configuration.

resource "null_resource" "core_requirements" {
    # Launch core after the internet proxy is up and configured
    depends_on = [ "null_resource.proxy_setup_final" ]

    triggers = {
        security_group = "${aws_security_group.backend.id}"
    }
}

resource "null_resource" "core_start_requirements" {
    # Wait for the hairpin egress to be available before starting the system
    depends_on = [ "null_resource.core_setup_mangle",
    	           "aws_security_group_rule.backend_egress_hairpin" ]

    triggers = {
        dummy = "dummy"
    }
}
