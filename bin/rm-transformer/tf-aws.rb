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
    @out['resource'] ||= []
    # To avoid cyclic dependencies, we use separate security group rules
    # instead of embedding them in the security group definitions
    @out['resource'] << { 'aws_security_group' => security_groups }
    @out['resource'] << {
      'aws_security_group_rule' => security_group_rules(manifest['roles'])
    }
    super(manifest)
  end

  def security_groups
    {
      'frontend' => {
        'tags' => {
          'Name' => '${var.cluster_prefix}-frontend'
        },
        'name' => '${var.cluster_prefix}-frontend',
        'description' => 'Frontend',
        'vpc_id' => '${aws_vpc.cluster.id}'
      }
    }
  end

  def security_group_rules(roles)
    rules = {}
    rules.merge! frontend_security_group_rules
    rules.merge! exposed_ports_security_group_rules('frontend', roles)
    rules
  end

  # Get the security group rules for the frontend machine
  # This may be a proxy in some configurations
  def frontend_security_group_rules
    {
      'frontend_egress' => {
        # Allow outbound traffic to all ports everywhere
        'security_group_id' => '${aws_security_group.frontend.id}',
        'type' => 'egress',
        'from_port' => 0,
        'to_port' => 0,
        'protocol' => '-1',
        'cidr_blocks' => ['0.0.0.0/0']
      }
    }
  end

  # Get the security group rules for exposed ports
  #
  # @param group_name [String] The name of the security group
  # @param roles      [Hash]   The roles definition
  # @returns          [Hash]   The exposed ports security group rules
  def exposed_ports_security_group_rules(group_name, roles)
    rules = {}
    get_exposed_ports(roles).each do |port|
      protocol = port['protocol'].downcase
      port_number = port['internal'].to_i
      rules["#{group_name}_ingress_#{protocol}_to_#{port_number}"] = {
        'security_group_id' => "${aws_security_group.#{group_name}.id}",
        'type' => 'ingress',
        'from_port' => port_number,
        'to_port' => port_number,
        'protocol' => protocol,
        'cidr_blocks' => ['0.0.0.0/0']
      }
    end
    rules
  end

  # # ## ### ##### ########
end

# # ## ### ##### ########
