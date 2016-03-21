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
  # Syntax: ?--dev? ?--provider <name>? <roles-manifest.yml>|- ?...?
  ##
  # --dev             ~ Include dev-only parts in the output
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
  # --env-dir <dir>   ~ Read all *.env files from this directory.
  #
  # ?...?               Additional files, format-dependent
  ##
  # The generated definitions are written to stdout

  provider = 'ucp'
  options = {
    dtr:         'docker.helion.lol',
    dtr_org:     'helioncf',
    hcf_version: 'develop',
    hcf_prefix:  'hcf'
  }
  env_dir = nil

  op = OptionParser.new do |opts|
    opts.banner = 'Usage: rm-transform [--dev] [--dtr NAME] [--dtr-org TEXT] [--hcf-version TEXT] [--provider ucp|tf|terraform] [--env-dir DIR] role-manifest|- ?...?

    Read the role-manifest from the specified file, or stdin (-),
    then transform according to the chosen provider (Default: ucp)
    The result is written to stdout.

'

    opts.on('-D', '--dtr location', 'Registry to get docker images from') do |v|
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
    opts.on('-d', '--dev', 'Include dev-only parts in the output') do |v|
      options[:dev] = v
    end
    opts.on('-e', '--env-dir [dir]', 'Directory containing *.env files') do |v|
      env_dir = v
    end
    opts.on('-p', '--provider format', 'Chose output format') do |v|
      provider = case v
                 when 'ucp'             then 'ucp'
                 when 'tf', 'terraform' then 'tf'
                 else abort "Unknown provider: #{v}"
                 end
    end
  end
  op.parse!

  if ARGV.empty? || provider.nil?
    op.parse!(['--help'])
    exit 1
  end

  origin = ARGV[0]

  the_roles = get_roles(origin, env_dir)
  provider = get_provider(provider).new(options, ARGV[1, ARGV.size])
  the_result = provider.transform(the_roles)

  puts(the_result)
end

def get_provider(name)
  # Convert provider name to package and class
  if name == 'ucp'
    require_relative 'rm-transformer/ucp'
    ToUCP
  elsif name == 'tf'
    require_relative 'rm-transformer/tf'
    ToTerraform
  end
end

def get_roles(path, env_dir)
  if path == '-'
    # Read from stdin.
    roles = YAML.load($stdin)
  else
    roles = YAML.load_file(path)
  end

  unless env_dir.nil? || env_dir == ''
    vars = roles['configuration']['variables']
    Dir.glob(File.join(env_dir, "*.env")).each do |env_file|
      File.readlines(env_file).each do |line|
        name, value = line.chomp.split('=', 2)
        i = vars.find_index{|x| x['name'] == name }
        if i.nil?
          STDERR.puts "Variable #{name} defined in #{env_file} does not exist in role manifest"
        else
          vars[i]['default'] = value
        end
      end
    end
  end

  return roles
end

  # Loaded structure
  ##
  # the_roles.roles[].name				/string
  # the_roles.roles[].dev-only				/bool
  # the_roles.roles[].type				/string (*)
  # the_roles.roles[].scripts[]				/string
  # the_roles.roles[].jobs[].name			/string
  # the_roles.roles[].jobs[].release_name		/string
  # the_roles.roles[].processes[].name			/string
  # the_roles.roles[].configuration.variables[].name	/string
  # the_roles.roles[].configuration.variables[].default	/string
  # the_roles.roles[].configuration.templates.<any>	/string
  # the_roles.roles[].run.capabilities[]		/string
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

main
