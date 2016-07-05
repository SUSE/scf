## HCP instance definition output provider
# # ## ### ##### ########

require 'json'
require_relative 'common'

# Provider to generate HCP instance definitions
class ToHCPInstance < Common
  def initialize(options)
    super(options)
    # In HCP the version number becomes a kubernetes label, which puts
    # some restrictions on the set of allowed characters and its
    # length.
    @hcf_version.gsub!(/[^a-zA-Z0-9.-]/, '-')
    @hcf_version = @hcf_version.slice(0,63)
  end

  # Public API
  def transform(manifest)
    JSON.pretty_generate(to_hcp_instance(manifest))
  end

  def to_hcp_instance(manifest)
    definition = load_template
    variables = (manifest['configuration'] || {})['variables']
    definition['parameters'] = []
    definition['parameters'].push(*get_uaa_parameter(manifest['auth']))
    definition['parameters'].push(*collect_parameters(variables))
    definition['sdl_version'] = @hcf_version
    definition['product_version'] = Common.product_version
    definition
  end

  # Load the instance definition template
  def load_template
    open(@options[:instance_definition_template], 'r') do |f|
      JSON.load f
    end
  end

  def get_uaa_parameter(auth_info)
    # Add in the UAA clients / authorities information like we do for vagrant
    # These aren't actually used, but we need the structure in place so
    # configgin doesn't choke when trying to add child properties
    return [] unless auth_info
    results = []
    if auth_info['clients']
      results << {
        'name' => 'UAA_CLIENTS',
        'value' => auth_info['clients'].to_json
      }
    end
    if auth_info['authorities']
      results << {
        'name' => 'UAA_USER_AUTHORITIES',
        'value' => auth_info['authorities'].to_json
      }
    end
    results
  end

  def collect_parameters(variables)
    results = []
    variables.each do |var|
      # HCP currently freaks out if it gets empty values
      next if var['default'].nil? || var['default'].empty?
      name = var['name']
      # secrets currently need to be lowercase and can only use dashes, not underscores
      # This should be handled by HCP instead: https://jira.hpcloud.net/browse/CAPS-184
      name.downcase!.gsub!('_', '-') if var['secret']
      value = var['default']
      # Some certificates coming from certs.env contain literal `\n` instead of line breaks
      value.gsub!('\\n', "\n")
      results << {
        'name' => name,
        'value' => value
      }
    end
    results
  end

end
