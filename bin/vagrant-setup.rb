#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
## ### ##### ########
# Tool to convert role-manifest.yml into various other forms
# - Vagrant : Use of EV in roles
# ... more

require 'optparse'
require 'yaml'
require 'json'
require_relative 'vagrant-setup/common'

def main
  # Syntax: ?--manual? ?--provider <name>? <roles-manifest.yml>|-
  ##
  # --manual          ~ Include manually started roles in the output
  # --property-map <file> ~ File mapping releases and jobs to the properties they use.
  # --provider <name> ~ Choose the output format.
  #                     Known: vagrant
  #                     Default: vagrant
  # --dtr             ~ Location of trusted docker registry
  #                     (Default: empty)
  # --dtr-org         ~ Org to use for images stored to the DTR
  #                     (Default: splatform)
  # --hcf-tag         ~ And tag to use for the same
  #                     (Default: develop)
  # --hcf-prefix      ~ The prefix used during image generation
  #                     (Default: hcf)
  #                     Used to construct the image names to look for.
  # --hcf-version     ~ Version of the service.
  #                     (Default: 0.0.0)
  ##
  # The generated definitions are written to stdout

  provider = 'vagrant'
  options = {
    dtr:         'docker.helion.lol',
    dtr_org:     'splatform',
    hcf_tag:     'develop',
    hcf_prefix:  'hcf',
    hcf_version: '0.0.0',
    hcf_root_dir: nil,
    manual:      false,
    propmap:     nil,
    rm_origin:   nil
  }

  op = OptionParser.new do |opts|
    opts.banner = 'Usage: vagrant-setup [--manual] [--hcf-root-dir PATH] [--hcf-version TEXT] [--dtr NAME] [--dtr-org TEXT] [--hcf-tag TEXT] [--provider vagrant] role-manifest|-

    Read the role-manifest from the specified file, or stdin (-),
    then transform according to the chosen provider (Default: vagrant)
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
    opts.on('-H', '--hcf-tag text', 'Tag to use for docker images') do |v|
      options[:hcf_tag] = v
    end
    opts.on('-P', '--hcf-prefix text', 'Prefix to use in docker images') do |v|
      options[:hcf_prefix] = v
    end
    opts.on('-V', '--hcf-version text', 'Version to use for the service') do |v|
      options[:hcf_version] = v
    end
    opts.on('-T', '--hcf-root-dir text', 'Absolute path of the HCF sources main directory') do |v|
      options[:hcf_root_dir] = v
    end
    opts.on('-m', '--manual', 'Include manually started roles in the output') do |v|
      options[:manual] = v
    end
    opts.on('-M', '--property-map text', 'Path to YAML file with the mapping from releases to jobs to properties') do |v|
      options[:propmap] = YAML.load_file(v)
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
  options[:rm_origin] = origin

  role_manifest = Common.load_role_manifest(origin)
  check_roles role_manifest['roles']

  provider = provider_constructor[provider].call.new(options)
  the_result = provider.transform(role_manifest)

  puts(the_result)
end

def provider_constructor
  ({
    'vagrant' => lambda {
      require_relative 'vagrant-setup/vagrant'
      ToVAGRANT
    },
  })
end



# Loaded structure
##
# the_roles.roles[].name				/string
# the_roles.roles[].type				/string (*)
# the_roles.roles[].scripts[]				/string
# the_roles.roles[].jobs[].name				/string
# the_roles.roles[].jobs[].release_name			/string
# the_roles.roles[].processes[].name			/string
# the_roles.roles[].configuration.variables[].name	/string
# the_roles.roles[].configuration.variables[].default	/string
# the_roles.roles[].configuration.templates.<any>	/string
# the_roles.roles[].run.capabilities[]			/string
# the_roles.roles[].run.flight-stage			/string (**)
# the_roles.roles[].run.persistent-volumes[].path	/string, mountpoint
# the_roles.roles[].run.persistent-volumes[].size	/float [GB]
# the_roles.roles[].run.shared-volumes[].path		/string, mountpoint
# the_roles.roles[].run.shared-volumes[].size		/float [GB]
# the_roles.roles[].run.shared-volumes[].tag		/string
# the_roles.roles[].run.memory				/float [MB]
# the_roles.roles[].run.virtual-cpus			/int
# the_roles.roles[].run.scaling.indexed			/int
# the_roles.roles[].run.scaling.min			/int
# the_roles.roles[].run.scaling.max			/int
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
