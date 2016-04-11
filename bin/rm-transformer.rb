#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
## ### ##### ########
# Tool to convert role-manifest.yml into various other forms
# - UCP definitions
# - (MPC) Terraform definitions
# ... more

require 'optparse'
require 'yaml'
require 'json'

def main
  # Syntax: ?--manual? ?--provider <name>? <roles-manifest.yml>|-
  ##
  # --manual          ~ Include manually started roles in the output
  # --provider <name> ~ Choose the output format.
  #                     Known: ucp, tf
  #                     Default: ucp
  # --dtr             ~ Location of trusted docker registry
  #                     (Default: empty)
  # --dtr-org         ~ Org to use for images stored to the DTR
  #                     (Default: helioncf)
  # --hcf-version     ~ And tag to use for the same
  #                     (Default: develop)
  # --hcf-prefix      ~ The prefix used during image generation
  #                     (Default: hcf)
  #                     Used to construct the image names to look for.
  # --env <dir>       ~ Read all *.env files from this directory.
  ##
  # The generated definitions are written to stdout

  provider = 'ucp'
  options = {
    dtr:         'docker.helion.lol',
    dtr_org:     'helioncf',
    hcf_version: 'develop',
    hcf_prefix:  'hcf',
    manual:      false
  }
  env_dir = nil

  op = OptionParser.new do |opts|
    opts.banner = 'Usage: rm-transform [--manual] [--dtr NAME] [--dtr-org TEXT] [--hcf-version TEXT] [--provider ucp|tf|tf:aws|tf:mpc] [--env-dir DIR] role-manifest|-

    Read the role-manifest from the specified file, or stdin (-),
    then transform according to the chosen provider (Default: ucp)
    The result is written to stdout.

'

    opts.on('-D', '--dtr location', 'Registry to get docker images from') do |v|
      # The dtr location is canonicalized to have no trailing "/".
      # If a trailing "/" should be needed by an output it is the provider's
      # responsibility to add it.
      v.chomp!("/")

      options[:dtr] = v
    end
    opts.on('-O', '--dtr-org text', 'Organization for docker images') do |v|
      options[:dtr_org] = v
    end
    opts.on('-H', '--hcf-version text', 'Label to use in docker images') do |v|
      options[:hcf_version] = v
    end
    opts.on('-P', '--hcf-prefix text', 'Prefix to use in docker images') do |v|
      options[:hcf_prefix] = v
    end
    opts.on('-m', '--manual', 'Include manually started roles in the output') do |v|
      options[:manual] = v
    end
    opts.on('-e', '--env-dir dir', 'Directory containing *.env files') do |v|
      env_dir = v
    end
    opts.on('-p', '--provider format', 'Chose output format') do |v|
      abort "Unknown provider: #{v}" if provider_constructor[v].nil?
      provider = v
    end
  end
  op.parse!

  if ARGV.length != 1 || provider.nil?
    op.parse!(['--help'])
    exit 1
  end

  origin = ARGV[0]

  role_manifest = load_role_manifest(origin, env_dir)
  check_roles role_manifest['roles']

  provider = provider_constructor[provider].call.new(options)
  the_result = provider.transform(role_manifest)

  puts(the_result)
end

def provider_constructor
  ({
    'ucp' => lambda {
      require_relative 'rm-transformer/ucp'
      ToUCP
    },
    'tf' => lambda {
      require_relative 'rm-transformer/tf'
      ToTerraform
    },
    'tf:aws' => lambda {
      require_relative 'rm-transformer/tf-aws'
      ToTerraformAWS
    },
    'tf:aws:proxy' => lambda {
      require_relative 'rm-transformer/tf-aws-proxy'
      ToTerraformAWSWithProxy
    },
    'tf:mpc' => lambda {
      require_relative 'rm-transformer/tf-mpc'
      ToTerraformMPC
    },
  })
end

def load_role_manifest(path, env_dir)
  if path == '-'
    # Read from stdin.
    role_manifest = YAML.load($stdin)
  else
    role_manifest = YAML.load_file(path)
  end

  unless env_dir.nil?
    vars = role_manifest['configuration']['variables']
    Dir.glob(File.join(env_dir, "*.env")).sort.each do |env_file|
      File.readlines(env_file).each do |line|
        next if /^($|\s*#)/ =~ line  # Skip empty lines and comments
        name, value = line.strip.split('=', 2)
        i = vars.find_index{|x| x['name'] == name }
        if i.nil?
          STDERR.puts "Variable #{name} defined in #{env_file} does not exist in role manifest"
        else
          vars[i]['default'] = value
        end
      end
    end
  end

  role_manifest
end

  # Loaded structure
  ##
  # the_roles.roles[].name				/string
  # the_roles.roles[].type				/string (*)
  # the_roles.roles[].scripts[]				/string
  # the_roles.roles[].jobs[].name			/string
  # the_roles.roles[].jobs[].release_name		/string
  # the_roles.roles[].processes[].name			/string
  # the_roles.roles[].configuration.variables[].name	/string
  # the_roles.roles[].configuration.variables[].default	/string
  # the_roles.roles[].configuration.templates.<any>	/string
  # the_roles.roles[].run.capabilities[]		/string
  # the_roles.roles[].run.flight-stage			/string (**)
  # the_roles.roles[].run.persistent-volumes[].path	/string, mountpoint
  # the_roles.roles[].run.persistent-volumes[].size	/float [GB]
  # the_roles.roles[].run.shared-volumes[].path		/string, mountpoint
  # the_roles.roles[].run.shared-volumes[].size		/float [GB]
  # the_roles.roles[].run.shared-volumes[].tag		/string
  # the_roles.roles[].run.memory			/float [MB]
  # the_roles.roles[].run.virtual-cpus			/int
  # the_roles.roles[].run.exposed-ports[].name		/string
  # the_roles.roles[].run.exposed-ports[].protocol	/string
  # the_roles.roles[].run.exposed-ports[].source	/int
  # the_roles.roles[].run.exposed-ports[].target	/int
  # the_roles.roles[].run.exposed-ports[].public	/bool
  # the_roles.roles[].run.hosts.<any>			/string (name -> ip-addr)
  # the_roles.configuration.variables[].name		/string
  # the_roles.configuration.variables[].default		/string
  # the_roles.configuration.variables[].example		/string
  # the_roles.configuration.variables[].secret		/bool
  # the_roles.configuration.templates.<any>		/string (key -> value)

  # (Ad *) Allowed: 'bosh' (default), 'bosh-task', and 'docker'
  # (Ad **) Allowed: 'flight' (default), 'pre-flight', 'post-flight', and 'manual'

# Sanity check the role definitions
def check_roles(roles)
  errors = []
  roles.each do |role|
    role_type = role.fetch('type', 'bosh')
    role_stage = role['run'].fetch('flight-stage', 'flight')

    unless ['bosh', 'bosh-task', 'docker'].include? role_type
      errors << "Role #{role['name']} has invalid type #{role_type}"
    end

    unless ['pre-flight', 'post-flight', 'flight', 'manual'].include? role_stage
      errors << "Role #{role['name']} has invalid flight-stage #{role_stage}"
    end

    if (role_type == 'bosh'      && role_stage != 'flight') ||
       (role_type == 'bosh-task' && role_stage == 'flight')
      errors << "Role #{role['name']} can't be a #{role_stage} role with type #{role_type}"
    end
  end

  unless errors.empty?
    STDERR.puts 'Found errors with role definitions:'
    errors.each do |error|
      STDERR.puts "    #{error}"
    end
    exit 1
  end
end

main
