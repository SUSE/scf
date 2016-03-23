# -*- coding: utf-8 -*-
## Terraform/AWS output provider
## Specialization of generic TF for AWS security groups.
# # ## ### ##### ########

require_relative 'tf'

# Provider for terraform declarations derived from a role-manifest.
# Takes additional files containing the execution context.
class ToTerraformAWS < ToTerraform
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
# Add a security group for the Frontend endpoints
resource "aws_security_group" "frontend" {
    tags {
        Name = "${var.cluster-prefix}-frontend"
    }

    name        = "${var.cluster-prefix}-frontend"
    description = "Frontend"
    vpc_id      = "${aws_vpc.cluster.id}"

    # Allow outbound traffic to all ports everywhere
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
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
    port     = port['source']

    emit <<RULE
    # Exposing #{name}
    ingress {
        from_port   = #{port}
        to_port     = #{port}
        protocol    = "#{protocol.downcase}"
        cidr_blocks = ["0.0.0.0/0"]
    }
RULE
  end

  def get_exposed_ports(roles)
    result = [ ssh_port ]

    roles.each do |role|
      # Skip everything without runtime data or ports
      next unless role['run']
      next unless role['run']['exposed-ports']
      next if     role['run']['exposed-ports'].empty?

      role['run']['exposed-ports'].each do |port|
        # Skip all internal ports
        next unless port['public']
        result.push(port)
      end
    end

    result
  end

  def ssh_port
    {
      'name'        => 'ssh',
      'protocol'    => 'tcp',
      'source'      => 22,
      'target'      => 22,
      'public'      => true
    }
  end

  # # ## ### ##### ########
end

# # ## ### ##### ########
