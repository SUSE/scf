# -*- coding: utf-8 -*-
## Terraform/MPC output provider
## Specialization of generic TF for OpenStack security groups.
# # ## ### ##### ########

require_relative 'tf'

# Provider for terraform declarations derived from a role-manifest.
# Takes additional files containing the execution context.
class ToTerraformMPC < ToTerraform
  def initialize(options, remainder)
    super(options,remainder)
  end

  # Internal definitions

  def to_terraform(manifest)
    emit_security_group(manifest['roles'])
    super(manifest)
  end

  def emit_security_group(roles)
    emit_sg_header
    get_exposed_ports(roles).map { |port| emit_sg_ingress(port) }
    emit_sg_trailer
  end

  def emit_sg_header
    emit <<HEADER
# Add a security group for the endpoints
resource "openstack_compute_secgroup_v2" "hcf-container-host-secgroup" {
    name = "${var.cluster-prefix}-container-host"
    description = "HCF Container Hosts"

    rule {
        from_port = 1
        to_port = 65535
        ip_protocol = "tcp"
        self = true
    }

    rule {
        from_port = 1
        to_port = 65535
        ip_protocol = "udp"
        self = true
    }

    # Allow inbound traffic on all the public ports named
    # in the role manifest, plus ssh (22).
HEADER
  end

  def emit_sg_trailer
    emit "}"
    emit ""
  end

  def emit_sg_ingress(port)
    name     = port['name']
    protocol = port['protocol']
    port     = port['target']

    emit <<RULE
    # Exposing #{name}
    rule {
        from_port   = #{port}
        to_port     = #{port}
        ip_protocol = "#{protocol.downcase}"
        cidr = "0.0.0.0/0"
    }
RULE
  end

  # # ## ### ##### ########
end

# # ## ### ##### ########
