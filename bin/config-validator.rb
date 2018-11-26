#!/usr/bin/env ruby
# frozen_string_literal: true

## ### ##### ########
# Tool to check role-manifest.yml for SCF-specific requirements

require 'yaml'
require 'json'
require 'pathname'
require_relative 'vagrant-setup/common'

DEFAULT_CONFIG_PATH = File.join(File.dirname(__FILE__),
                                '../container-host-files/etc/scf/config/')
SCRIPT_HA     = 'scripts/configure-HA-hosts.sh'
SCRIPT_SYSLOG = 'scripts/forward_logfiles.sh'

# HashAccessor makes Hash act sort of like OpenStruct
module HashAccessor
  refine Hash do
    def method_missing(method, *arguments)
      if method.to_s.end_with? '='
        raise "Invalid assignment using #{method} with #{arguments}" unless arguments.length == 1
        method = method.to_s unless key? method
        update(method.chomp('=') => arguments.first)
      else
        method = method.to_s unless key? method
        fetch(method, nil)
      end
    end
  end
end
using HashAccessor

def main
  STDOUT.sync = true
  @has_errors = 0
  @has_warnings = 0

  STDOUT.puts 'Running SCF-specific configuration checks ...'

  bosh_properties = YAML.safe_load(ARGF.read)
  # :: hash (release -> hash (job -> hash (property -> default)))

  manifest_file = ENV.fetch('FISSILE_ROLE_MANIFEST', File.expand_path(File.join(DEFAULT_CONFIG_PATH, 'role-manifest.yml')))
  manifest = Common.load_role_manifest(manifest_file)
  manifest.configuration ||= {}

  templates = {}
  if manifest.configuration.templates
    templates['__global__'] = manifest['configuration']['templates']
  end
  manifest.instance_groups.each do |r|
    r.configuration ||= {}
    templates[r.name] = r.configuration.templates if r.configuration.templates
  end

  STDOUT.puts "\nCheck clustering".cyan
  check_clustering(manifest, bosh_properties)

  STDOUT.puts "\nAll BOSH roles must forward syslog".cyan
  check_roles_forward_syslog(manifest, bosh_properties)

  # print a report with information about our config
  print_report(manifest, bosh_properties, templates)

  message = "\nConfiguration check"

  message = if @has_errors > 0
              (message + " failed (#{@has_errors} errors)").red
            else
              (message + ' passed').green
            end
  message += ' ' + "(#{@has_warnings} warnings)".yellow if @has_warnings > 0

  STDOUT.puts message
  exit 1 if @has_errors > 0
end

def print_report(manifest, bosh_properties, templates)
  role_count = manifest.instance_groups.length
  bosh_properties_count = bosh_properties.inject([]) do |all_props, (_, jobs)|
    jobs.each do |(_, properties)|
      all_props << properties
    end
  end.flatten.uniq.length
  template_count = templates.inject([]) do |all_templates, (_, template_list)|
    all_templates << template_list.keys
  end.flatten.length
  scripts_dir = File.expand_path(File.join(__FILE__, '../../container-host-files/etc/scf/config/scripts'))
  scripts = Dir.glob(File.join(scripts_dir, '**/*')).reject { |fn| File.directory?(fn) }
  rm_parameters = manifest['variables']

  STDOUT.puts "\nConfiguration info:"
  STDOUT.puts "#{role_count.to_s.rjust(10, ' ').cyan} roles"
  STDOUT.puts "#{bosh_properties_count.to_s.rjust(10, ' ').cyan} BOSH properties"
  STDOUT.puts "#{template_count.to_s.rjust(10, ' ').cyan} role manifest templates"
  STDOUT.puts "#{scripts.length.to_s.rjust(10, ' ').cyan} scripts"
  STDOUT.puts "#{rm_parameters.length.to_s.rjust(10, ' ').cyan} role manifest variables"
end

def for_each_role_job(manifest, bosh_properties, role_action)
  manifest.instance_groups.each do |role|
    role.configuration ||= {}
    role_action.call role, (lambda do |job_action|
      role.fetch('jobs', []).each do |job|
        unless bosh_properties.key? job.release
          STDOUT.puts "Role #{role.name} has job #{job.name} from unknown release #{job.release}"
          @has_errors += 1
          next
        end
        unless bosh_properties[job.release].key? job.name
          STDOUT.puts "Role #{role.name} has job #{job.name} not in release #{job.release}"
          @has_errors += 1
          next
        end

        job_action.call(job)
      end
    end)
  end
end

# Checks that all roles required any of the clustering parameters use
# scripts/configure-HA-hosts.sh and that all roles which don't will
# not.
def check_clustering(manifest, bosh_properties)
  # :: hash (release -> hash (job -> hash (property -> default)))

  params = {}
  manifest.configuration.templates.each do |property, template|
    params[property] = Common.parameters_in_template(template)
  end
  rparams = nil
  collected_params = nil

  for_each_role_job(manifest, bosh_properties, lambda { |role, block|
    rparams = params.dup
    role.configuration.fetch('templates', {}).each do |property, template|
      rparams[property] = Common.parameters_in_template(template)
    end

    collected_params = Hash.new { |h, parameter| h[parameter] = [] }
    # collected_params :: hash (parameter -> array (pair (job,release)))
    # And default unknown elements as empty list.

    block.call(lambda do |job|
      bosh_properties[job.release][job.name].each_key do |property|
        rparams.fetch("properties.#{property}", []).each do |param|
          next unless param == "KUBE_NATS_CLUSTER_IPS"
          collected_params[param] << "Job #{job.name.red} in release #{job.release.red}"
        end
      end
    end)

    if collected_params.empty?
      next unless script?(role, SCRIPT_HA)
      STDOUT.puts "Superfluous use of #{SCRIPT_HA.red} by role #{role['name'].red}"
      @has_errors += 1
    else
      next if script?(role, SCRIPT_HA)
      # secrets-generation uses KUBERNETES_CLUSTER_DOMAIN for cert generation but is not an HA role itself
      next if role['name'] == 'secret-generation'
      STDOUT.puts "Missing #{SCRIPT_HA.red} in role #{role['name'].red}, requested by"
      collected_params.each do |param, jobs|
        STDOUT.puts "- #{param.red}"
        jobs.each do |job_desc|
          STDOUT.puts "  - #{job_desc}"
        end
      end
      @has_errors += 1
    end
  })
end

def script?(role_manifest, script)
  role_manifest.fetch('environment_scripts', []).include? script
end

# Checks that all BOSH roles have the syslog forwarding script
def check_roles_forward_syslog(manifest, bosh_properties)
  for_each_role_job(manifest, bosh_properties, lambda { |role, block|
    next unless (role.type || 'bosh').casecmp('bosh').zero?
    scripts = [] + (role.scripts || []) + (role.environment_scripts || [])
    next if scripts.include? SCRIPT_SYSLOG
    STDOUT.puts "role #{role['name'].red} does not include #{SCRIPT_SYSLOG}"
    @has_errors += 1
    block.call lambda do |job|
      # don't care
    end
  })
end

main
