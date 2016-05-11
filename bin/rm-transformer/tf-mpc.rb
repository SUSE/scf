# -*- coding: utf-8 -*-
## Terraform/MPC output provider
## Specialization of generic TF for OpenStack security groups.
# # ## ### ##### ########

require_relative 'tf'

# Provider for terraform declarations derived from a role-manifest.
# Takes additional files containing the execution context.
class ToTerraformMPC < ToTerraform
  # Internal definitions

  def to_terraform(manifest)
    emit_security_group(manifest['roles'])
    super(manifest)
  end

  def emit_security_group(roles)
    rules = [
      {
        'from_port' => 1,
        'to_port' => 65535,
        'ip_protocol' => 'tcp',
        'self' => true
      },
      {
        'from_port' => 1,
        'to_port' => 65535,
        'ip_protocol' => 'udp',
        'self' => true
      }
    ]
    get_exposed_ports(roles).each do |port|
      rules << {
        'from_port' => port['target'],
        'to_port' => port['target'],
        'ip_protocol' => port['protocol'].downcase,
        'cidr' => '0.0.0.0/0'
      }
    end
    @out['resource'] ||= []
    @out['resource'] << {
      'openstack_compute_secgroup_v2' => {
        'hcf-container-host-secgroup' => {
          'name' => '${var.cluster_prefix}-container-host',
          'description': 'HCF Container Hosts',
          'rule' => rules
        }
      }
    }
  end

  # # ## ### ##### ########
end

# # ## ### ##### ########
