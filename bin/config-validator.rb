#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
## ### ##### ########
# Tool to check role-manifest.yml, opinions.yml, dark-opinions.yml for inconsistencies.

#require 'optparse'
require 'yaml'
require 'json'
require 'pathname'
require_relative 'rm-transformer/common'

class String
  def red
    "\033[0;31m#{self}\033[0m"
  end

  def green
    "\033[0;32m#{self}\033[0m"
  end

  def cyan
    "\033[0;36m#{self}\033[0m"
  end
end

def main
  STDOUT.sync = true
  @has_errors = false

  STDOUT.puts "Running configuration checks ..."


  bosh_properties = JSON.load(ARGF.read)

  manifest_file = File.expand_path(File.join(__FILE__, '../../container-host-files/etc/hcf/config/role-manifest.yml'))
  light_opinions_file = File.expand_path(File.join(__FILE__, '../../container-host-files/etc/hcf/config/opinions.yml'))
  dark_opinions_file = File.expand_path(File.join(__FILE__, '../../container-host-files/etc/hcf/config/dark-opinions.yml'))

  manifest = Common.load_role_manifest(manifest_file, {})
  light = YAML.load_file(light_opinions_file)
  dark = YAML.load_file(dark_opinions_file)

  light = flatten(light)
  dark = flatten(dark)

  templates = {}
  if manifest['configuration'] && manifest['configuration']['templates']
    templates['__global__'] = manifest['configuration']['templates']
  end
  manifest['roles'].each do |r|
    next unless r['configuration']
    next unless r['configuration']['templates']
    templates[r['name']] = r['configuration']['templates']
  end

  STDOUT.puts "\nAll dark opinions must be configured as templates".cyan
  dark_exposed(templates, dark)

  STDOUT.puts "\nNo dark opinions must have defaults in light opinions".cyan
  dark_unexposed(light, dark)

  STDOUT.puts "\nNo duplicates must exist between role manifest and opinions".cyan
  templates.each do |label, defs|
    check(defs,light)
  end

  STDOUT.puts "\nAll properties must be defined in a BOSH release".cyan
  templates.each do |label, defs|
    check_bosh_properties(defs, bosh_properties, "role-manifest template")
  end

  STDOUT.puts "\nAll opinions must exist in a bosh release".cyan
  check_bosh_properties(light, bosh_properties, "light opinion")

  STDOUT.puts "\nAll dark opinions must exist in a bosh release".cyan
  check_bosh_properties(dark, bosh_properties, "dark opinion")

  STDOUT.puts "\nAll vars in env files must exist in the role manifest".cyan
  env_dir = File.expand_path(File.join(__FILE__, '../settings'))
  all_env_dirs = Dir.glob(File.join(env_dir, "**/*/")) << env_dir
  dev_env = Common.collect_dev_env(all_env_dirs)
  check_env_files(manifest, dev_env)

  STDOUT.puts "\nAll role manifest params must be used".cyan
  check_rm_variables(manifest)

  STDOUT.puts "\nThe role manifest must not contain any constants in the global section".cyan
  check_non_templates(manifest)

  STDOUT.puts "\nAll of the scripts must be used".cyan
  check_role_manifest_scripts(manifest)

  # print a report with information about our config
  print_report(manifest, bosh_properties, templates, light, dark, dev_env)

  if @has_errors
    STDOUT.puts "\nConfiguration check failed".red
    exit 1
  else
    STDOUT.puts "\nConfiguration check passed".green
  end
end

def print_report(manifest, bosh_properties, templates, light, dark, dev_env)
  role_count = manifest['roles'].length
  bosh_properties_count = bosh_properties.inject([]) {|all_props, (_, jobs)|
      jobs.inject(all_props) {|all_props, (_, properties)|
        all_props << properties
      }
    }.flatten.uniq.length
  template_count = templates.inject([]) {|all_templates, (_, template_list)|
      all_templates << template_list.keys
    }.flatten.length
  scripts_dir = File.expand_path(File.join(__FILE__, '../../container-host-files/etc/hcf/config/scripts'))
  scripts = Dir.glob(File.join(scripts_dir, "**/*")).reject {|fn| File.directory?(fn) }
  rm_parameters = manifest['configuration']['variables']

  STDOUT.puts "\nConfiguration info:"
  STDOUT.puts "#{role_count.to_s.rjust(10, ' ').cyan} roles"
  STDOUT.puts "#{bosh_properties_count.to_s.rjust(10, ' ').cyan} BOSH properties"
  STDOUT.puts "#{template_count.to_s.rjust(10, ' ').cyan} role manifest templates"
  STDOUT.puts "#{light.length.to_s.rjust(10, ' ').cyan} opinions"
  STDOUT.puts "#{dark.length.to_s.rjust(10, ' ').cyan} dark opinions"
  STDOUT.puts "#{dev_env.length.to_s.rjust(10, ' ').cyan} dev env vars"
  STDOUT.puts "#{scripts.length.to_s.rjust(10, ' ').cyan} scripts"
  STDOUT.puts "#{rm_parameters.length.to_s.rjust(10, ' ').cyan} role manifest variables"
end

# Makes sure that all scripts are being used in the role manifest
def check_role_manifest_scripts(manifest)
  manifest_dir = File.expand_path(File.join(__FILE__, '../../container-host-files/etc/hcf/config/'))
  scripts_dir = File.expand_path(File.join(__FILE__, '../../container-host-files/etc/hcf/config/scripts'))

  scripts = Dir.glob(File.join(scripts_dir, "**/*")).reject {|fn| File.directory?(fn) }

  scripts.each do |script|
    relative_path = Pathname.new(script).relative_path_from(Pathname.new(manifest_dir))

    found = manifest['roles'].any? {|r|
      (r['scripts'] || []).concat(r['post_config_scripts'] || []).concat(r['environment_scripts'] || []).include?(relative_path.to_s)
    }

    unless found
      STDOUT.puts "script #{relative_path.to_s.red} is not used in the role manifest"
      @has_errors = true
    end
  end
end

# Checks that all of the env vars in the dev env files are declared in the role manifest
def check_env_files(role_manifest, dev_env)
  vars = role_manifest['configuration']['variables']
  dev_env.each_pair do |name, (env_file, value)|
    next if special_env(name)
    i = vars.find_index{|x| x['name'] == name }
    if i.nil?
      STDOUT.puts "dev env var #{name.red} defined in #{env_file.red} does not exist in role manifest"
      @has_errors = true
    end
  end
end

# Checks that none of the role manifest templates are used as constants
def check_non_templates(manifest)
  templates = manifest['configuration']['templates'].values

  manifest['configuration']['templates'].each do |property, template|
    empty = Common.parameters_in_template(template).length == 0

    if empty
      STDOUT.puts "global role manifest template #{property.red} is used as a constant"
      @has_errors = true
    end
  end
end


# Checks if all role manifest params are being used in a template
def check_rm_variables(manifest)
  templates = manifest['configuration']['templates'].values

  manifest['roles'].each do |r|
    next unless r['configuration']
    next unless r['configuration']['templates']
    templates << r['configuration']['templates'].values
  end

  manifest['configuration']['variables'].each do |variable|
    found = templates.any? {|template|
      Common.parameters_in_template(template).include?(variable['name'])
    }

    unless found
      STDOUT.puts "role manifest variable #{variable['name'].red} was not found in any role manifest template"
      @has_errors = true
    end
  end
end

# Check to see if all properties are defined in a BOSH release
def check_bosh_properties(defs, bosh_properties, check_type)
  defs.each do |prop, _|
    next if special(prop)
    next unless prop.start_with? 'properties.'

    bosh_property = prop.sub(/^properties./, '')

    unless property_exists_in_bosh?(bosh_property, bosh_properties)
      STDOUT.puts "#{check_type} #{bosh_property.red} was not found in any bosh release"
      @has_errors = true
    end
  end
end

def property_exists_in_bosh?(property, bosh_properties)
  bosh_properties.any? {|_, jobs|
    jobs.any? {|_, property_list|
      property_list.include? property
    }
  }
end

def dark_exposed(templates, dark)
  # Everything in dark must have a definition in the
  # role-manifest, i.e. be exposed to the user
  dark.each do |k,v|
    next if contains(templates,k)
    STDOUT.puts "dark-opinion #{k.red} missing template in role-manifest"
    @has_errors = true
  end
end

def contains(templates,k)
  templates.each do |role, defs|
    next unless defs
    return true if defs[k]
  end
  false
end

def dark_unexposed(light,dark)
  # Nothing in dark must be in the light.
  dark.each do |property,v|
    next unless light[property]
    STDOUT.puts "dark-opinion #{property.red} found in light-opinions"
    @has_errors = true
  end
end

def check(defs,light)
  # Templates in the role manifest should not have anything in the opinions.
  # If the values are identical it should just be in opinions.
  # If they are different, then the opinions are superflous.

  sep = false

  defs.each do |property, value|
    next unless light[property]
    if value.to_s == light[property].to_s
      STDOUT.puts "duplicated #{property.red}"
      @has_errors = true
      sep = true
    end
  end

  STDOUT.puts "" if sep

  defs.each do |property, value|
    next unless light[property]
    if value.to_s != light[property].to_s
      @has_errors = true
      STDOUT.puts "conflict for #{property.red}"
      STDOUT.puts "  manifest: |#{value}|"
      STDOUT.puts "  opinion:  |#{light[property]}|"
    end
  end
end

def flatten(input)
  defs = {}
  collect(defs, '', input)
  defs
end

def collect(defs,prefix,input)
  return unless input.kind_of?(Hash)
  input.each do |k,v|
    key = prefix + k

    if v.kind_of?(Hash)
      collect(defs, key + '.', v)
      next
    end
    defs[key] = v
  end
end

def special(key)
  # Detect keys with structured values "collect" must not recurse into.
  return true if key =~ /^properties.cc.security_group_definitions/
  return true if key =~ /^properties.ccdb.roles/
  return true if key =~ /^properties.uaadb.roles/
  return true if key =~ /^properties.uaa.clients/
  return true if key =~ /^properties.cc.quota_definitions/
  false
end

def special_env(key)
  # Detect env var keys that are special (they are used, but not defined in the role manifest).
  return true if key =~ /^HCP_/
  return true if key == 'http_proxy'
  return true if key == 'https_proxy'
  return true if key == 'no_proxy'
  return true if key == 'HTTP_PROXY'
  return true if key == 'HTTPS_PROXY'
  return true if key == 'NO_PROXY'
  false
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

main
