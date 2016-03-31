# -*- coding: utf-8 -*-
## Terraform/AWS output provider
## Specialization of generic TF for AWS security groups.
# # ## ### ##### ########

require_relative 'tf'

# Provider for terraform declarations derived from a role-manifest.
# Takes additional files containing the execution context.
class ToTerraformAWS < ToTerraform
  # Internal definitions

  def to_terraform(manifest)
    emit_security_group(manifest['roles'])
    super(manifest)
  end

  def emit_security_group(roles)
    rules = get_exposed_ports(roles).map do |port|
      ({
        'from_port' => port['target'],
        'to_port' =>   port['target'],
        'protocol' => port['protocol'].downcase,
        'cidr_blocks' => ['0.0.0.0/0']
      })
    end

    @out['resource'] ||= []
    @out['resource'] << {
      # Add a security group for the Frontend endpoints
      'aws_security_group' => {
        'frontend' => {
          'tags' => {
            'Name' => '${var.cluster-prefix}-frontend'
          },
          'name' => '${var.cluster-prefix}-frontend',
          'description' => 'Frontend',
          'vpc_id' => '${aws_vpc.cluster.id}',
          'egress' => [
            # Allow outbound traffic to all ports everywhere
            {
              'from_port' => 0,
              'to_port' => 0,
              'protocol' => '-1',
              'cidr_blocks' => ['0.0.0.0/0']
            }
          ],
          'ingress' => rules
        }
      }
    }
  end

  # # ## ### ##### ########
end

# # ## ### ##### ########
