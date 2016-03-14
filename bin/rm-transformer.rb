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
  #
  # ?...?               Additional files, format-dependent
  ##
  # The generated definitions are written to stdout

  $options = {}
  provider = 'ucp'

  op = OptionParser.new do |opts|
    opts.banner = 'Usage: rm-transform [--dev] [--dtr NAME] [--dtr-org TEXT] [--hcf-version TEXT] [--provider ucp|tf|terraform] role-manifest|- ?...?

        Read the role-manifest from the specified file, or stdin (-),
        then transform according to the chosen provider (Default: ucp)
        The result is written to stdout.

        --dtr         - a docker trusted registry to use for image source (Default: docker.helion.lol)
        --dtr-org     - a docker trusted registry organization used for image source (Default: helioncf)
        --hcf-version - the version of hcf to use as an image source (Default: develop)
        --hcf-prefix  - the prefix used during image generation (Default: hcf)
'

    opts.on('-D', '--dtr location', 'Registry to get docker images from') do |v|
      $options[:dtr] = v
    end
    opts.on('-O', '--dtr-org text', 'Organization for docker images') do |v|
      $options[:dtr_org] = v
    end
    opts.on('-H', '--hcf-version text', 'Label to use in docker images') do |v|
      $options[:hcf_version] = v
    end
    opts.on('-P', '--hcf-prefix text', 'Prefix to use in docker images') do |v|
      $options[:hcf_prefix] = v
    end
    opts.on('-d', '--dev', 'Include dev-only parts in the output') do |v|
      $options[:dev] = v
    end
    opts.on('-p', '--provider format', 'Chose output format') do |v|
      provider = if v == 'ucp'
                   v
                 elsif v == 'tf' || v == 'terraform'
                   'tf'
                 end
    end
  end
  op.parse!

  if ARGV.empty? || provider.nil?
    op.parse!(['--help'])
    exit 1
  end

  origin = ARGV[0]

  the_roles = get_roles(origin)
  provider = get_provider(provider).new($options, ARGV[1, ARGV.size])
  the_result = provider.transform(the_roles)

  $stdout.puts(the_result)
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
