# -*- coding: utf-8 -*-
## Terraform/AWS with proxy output provider
## Specialization of generic TF to test a proxied configuration
# # ## ### ##### ########

require_relative 'tf-aws'

class ToTerraformAWSWithProxy < ToTerraformAWS

  def special_variables
    super + %w(HTTP_PROXY http_proxy HTTPS_PROXY https_proxy)
  end

  def security_groups
    super.merge(
      'backend' => {
        'tags' => {
          'Name' => '${var.cluster-prefix}-backend'
        },
        'name' => '${var.cluster-prefix}-backend',
        'description' => 'Backend',
        'vpc_id' => '${aws_vpc.cluster.id}'
      }
    )
  end

  def security_group_rules(roles)
    rules = {}
    rules.merge! frontend_security_group_rules
    rules.merge! exposed_ports_security_group_rules('backend', roles)
    rules.merge! backend_security_group_rules
    rules
  end

  def frontend_security_group_rules
    super.merge(
      'frontend_ingress_ssh' => {
        # Allow proxy inbound traffic to sshd
        'security_group_id' => '${aws_security_group.frontend.id}',
        'type' => 'ingress',
        'from_port' => 22,
        'to_port' => 22,
        'protocol' => 'tcp',
        'cidr_blocks' => ['0.0.0.0/0']
      },
      'frontend_ingress_http_proxy' => {
        # Allow proxy inbound traffic to sshd
        'security_group_id' => '${aws_security_group.frontend.id}',
        'type' => 'ingress',
        'from_port' => 3128,
        'to_port' => 3128,
        'protocol' => 'tcp',
        'source_security_group_id' => '${aws_security_group.backend.id}'
      }
    )
  end

  def backend_security_group_rules
    {
      'backend_egress_self' => {
        # Allow core outbound traffic to itself
        'security_group_id' => '${aws_security_group.backend.id}',
        'type' => 'egress',
        'from_port' => 0,
        'to_port' => 0,
        'protocol' => '-1',
        'self' => true
      },
      'backend_egress_frontend' => {
        # Allow core outbound traffic to the proxy
        'security_group_id' => '${aws_security_group.backend.id}',
        'type' => 'egress',
        'from_port' => 3128,
        'to_port' => 3128,
        'protocol' => 'tcp',
        'source_security_group_id' => '${aws_security_group.frontend.id}'
      },
      'backend_egress_hairpin' => {
        # Allow core outbound traffic to itself via the public IP
        'security_group_id' => '${aws_security_group.backend.id}',
        'type' => 'egress',
        'from_port' => 0,
        'to_port' => 0,
        'protocol' => '-1',
        'cidr_blocks' => ['${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}/32']
      }
    }
  end
end
