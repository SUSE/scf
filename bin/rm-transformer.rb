#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
## ### ##### ########
# Tool to convert role-manifest.yml into various other forms
# - UCP definitions
# - (MPC) Terraform definitions   [MPC for now, TODO: Read and merge fixed parts from support file]
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
  # ?...?               Additional files, format-dependent
  ##
  # The generated definitions are written to stdout

  $options = {}
  provider = 'ucp'

  op = OptionParser.new do |opts|
    opts.banner = 'Usage: rm-transform [--dev] [--provider ucp|tf|terraform] role-manifest|- ?...?

        Read the role-manifest from the specified file, or stdin (-),
        then transform according to the chosen provider (Default: ucp)
        The result is written to stdout.

'

    opts.on('-d', '--dev', 'Include dev-only parts in the output') do |v|
      $options[:dev] = v
    end
    opts.on('-p', '--provider format', 'Chose output format') do |v|
      if v == 'ucp'
        provider = v
      elsif v == 'tf' || v == 'terraform'
        provider = 'tf'
      else
        provider = nil
      end
    end
  end
  op.parse!

  if ARGV.empty? || provider.nil?
    op.parse!(['--help'])
    exit 1
  end

  origin = ARGV[0]

  # Convert provider name to package and class
  if provider == 'ucp'
    require_relative 'rm-transformer/ucp'
    provider = ToUCP
  elsif provider == 'tf'
    require_relative 'rm-transformer/tf'
    provider = ToTerraform
  end

  the_roles = get_roles(origin)
  the_result = provider.new($options, ARGV[1, ARGV.size]).transform(the_roles)

  $stdout.puts(the_result)
end

def get_roles(path)
  if path == '-'
    # Read from stdin.
    YAML.load($stdin)
  else
    YAML.load_file(path)
  end
  # Loaded structure
  ##
  # the_roles.roles[].name				/string
  # the_roles.roles[].dev-only				/bool
  # the_roles.roles[].type				/string (allowed "bosh-task")
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
  # the_roles.configuration.templates.<any>		/string (key -> value)
end

main
