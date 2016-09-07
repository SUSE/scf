## HCP instance definition output provider
# # ## ### ##### ########

require 'json'
require_relative 'common'

# Provider to generate HCP instance definitions
class ToHCPInstance < Common
  # Public API
  def transform(manifest)
    JSON.pretty_generate(to_hcp_instance(manifest))
  end

  def to_hcp_instance(manifest)
    definition = load_template

    dev_env = Common.collect_dev_env(env_dirs)

    vars = manifest['configuration']['variables']

    dev_env.each_pair do |name, (_, value)|
      i = vars.find_index{|x| x['name'] == name }
      vars[i]['default'] = value unless i.nil?
    end

    variables = (manifest['configuration'] || {})['variables']
    definition['parameters'] = []
    definition['parameters'].push(*collect_parameters(variables))
    definition['sdl_version'] = @hcf_version
    definition['product_version'] = Common.product_version
    definition
  end

  # Load the instance definition template
  def load_template
    json = File.read(@options[:instance_definition_template])
    templ = JSON.parse(json)

    templ['name']        ||= "hcf"
    templ['vendor']      ||= "HPE"
    templ['labels']      ||= ["my-hcf-cluster"]
    templ['instance_id'] ||= "my-hcf-cluster"
    templ['description'] ||= "HCF test cluster"

    templ
  end

  def env_dirs
    ['bin/settings', 'bin/settings/hcp']
  end

  def collect_parameters(variables)
    results = []
    variables.each do |var|
      # HCP currently freaks out if it gets empty values
      value = var['default']
      next if value.nil? || value.to_s.empty?
      name = var['name']
      # secrets currently need to be lowercase and can only use dashes, not underscores
      # This should be handled by HCP instead: https://jira.hpcloud.net/browse/CAPS-184
      name.downcase!.gsub!('_', '-') if var['secret']
      begin
        # Some certificates coming from certs.env contain literal `\n`
        # instead of line breaks. We rescue ourselves from trouble
        # with applying this to non-string values (port numbers,
        # boolean flag, etc.)
        value.gsub!('\\n', "\n")
      rescue
      end
      results << {
        'name' => name,
        'value' => value.to_s
      }
    end
    results
  end

end
