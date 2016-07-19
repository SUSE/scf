## HCP instance definition output provider
# # ## ### ##### ########

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
    definition['parameters'] = collect_parameters(variables)
    definition['sdl_version'] = @hcf_version
    definition['product_version'] = "4.0.0"
    definition
  end

  # Load the instance definition template
  def load_template
    open(@options[:instance_definition_template], 'r') do |f|
      JSON.load f
    end
  end

  def collect_parameters(variables)
    results = []
    variables.each do |var|
      unless var['secret']
        next unless ['DOMAIN'].include? var['name']
      end
      # HCP currently freaks out if it gets empty values
      next if var['default'].nil? || var['default'].empty?
      name = var['name']
      # secrets currently need to be lowercase and can only use dashes, not underscores
      # This should be handled by HCP instead: https://jira.hpcloud.net/browse/CAPS-184
      name.downcase!.gsub!('_', '-') if var['secret']
      results << {
        'name' => name,
        'value' => var['default']
      }
    end
    results
  end

end
