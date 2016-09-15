#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
## ### ##### ########
# Tool to check role-manifest.yml, opinions.yml, dark-opinions.yml for inconsistencies.

#require 'optparse'
require 'yaml'
require 'json'
require 'pathname'
require_relative 'rm-transformer/common'

def main
  STDOUT.sync = true
  @has_errors = 0
  @has_warnings = 0
  @configure_ha = "scripts/configure-HA-hosts.sh"

  STDOUT.puts "Running configuration checks ..."

  bosh_properties = YAML.load(ARGF.read)
  # :: hash (release -> hash (job -> hash (property -> default)))

  manifest_file = File.expand_path(File.join(__FILE__, '../../container-host-files/etc/hcf/config/role-manifest.yml'))
  light_opinions_file = File.expand_path(File.join(__FILE__, '../../container-host-files/etc/hcf/config/opinions.yml'))
  dark_opinions_file = File.expand_path(File.join(__FILE__, '../../container-host-files/etc/hcf/config/dark-opinions.yml'))

  manifest = Common.load_role_manifest(manifest_file)
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

  global_variables = global_variables(manifest)

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

  global_defaults = global_defaults(bosh_properties)

  STDOUT.puts "\nAll bosh properties in a release should have the same default across jobs".cyan
  check_bosh_defaults(global_defaults)

  STDOUT.puts "\nAll light opinions should differ from their defaults in the bosh releases".cyan
  check_light_defaults(light, global_defaults)

  STDOUT.puts "\nAll vars in env files must exist in the role manifest".cyan
  env_dir = File.expand_path(File.join(__FILE__, '../settings'))
  all_env_dirs = Dir.glob(File.join(env_dir, "**/*/")) << env_dir
  dev_env = Common.collect_dev_env(all_env_dirs)
  check_env_files(manifest, dev_env)

  STDOUT.puts "\nAll role manifest params must be used".cyan
  check_rm_variables(manifest)

  STDOUT.puts "\nAll role manifest templates must use only declared params".cyan
  check_rm_templates(templates, manifest, global_variables)

  STDOUT.puts "\nThe role manifest must not contain any constants in the global section".cyan
  check_non_templates(manifest)

  STDOUT.puts "\nAll of the scripts must be used".cyan
  check_role_manifest_scripts(manifest)

  STDOUT.puts "\nCheck clustering".cyan
  check_clustering(manifest, bosh_properties)

  STDOUT.puts "\nThe run.env references of docker roles must use only declared params".cyan
  check_docker_run_env(manifest, global_variables)

  STDOUT.puts "\nNo non-docker role may declare 'run.env'".cyan
  check_nondocker_run_env(manifest)

  # print a report with information about our config
  print_report(manifest, bosh_properties, templates, light, dark, dev_env)

  message = "\nConfiguration check"

  if @has_errors > 0
    message = (message + " failed (#{@has_errors} errors)").red
  else
    message = (message + " passed").green
  end
  if @has_warnings > 0
    message += " " + "(#{@has_warnings} warnings)".yellow
  end

  STDOUT.puts message
  exit 1 if @has_errors > 0
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

# Makes sure the run.env of docker roles uses only declared params
# (see also check_rm_templeates).
def check_docker_run_env(manifest, global_variables)
  # Report all roles with run.env elements which reference unknown
  # parameters, and the bogus parameters themselves.  We ignore the
  # parameters provided by HCP, and the proxy parts, these are ok.

  manifest['roles'].each do |role|
    next unless role['type'] == 'docker'
    next unless role['run']
    next unless role['run']['env']

    # Docker role with run.env references. Check against declared
    # parameters.

    role['run']['env'].each do |vname|
      report_bogus_variable("Docker role #{role['name'].red} run.env", vname, global_variables)
    end
  end
end

# Makes sure that no non-docker roles have run.env
def check_nondocker_run_env(manifest)
  manifest['roles'].each do |role|
    next if role['type'] == 'docker'
    next unless role['run']
    next unless role['run']['env']

    STDOUT.puts "Non-docker role #{role['name'].red} declares bogus parameters (run.env)"
    @has_errors += 1
  end
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

    next if found
    STDOUT.puts "script #{relative_path.to_s.red} is not used in the role manifest"
    @has_errors += 1
  end
end

# Checks that all of the env vars in the dev env files are declared in the role manifest
def check_env_files(role_manifest, dev_env)
  vars = role_manifest['configuration']['variables']
  dev_env.each_pair do |name, (env_file, value)|
    next if Common.special_env(name)
    i = vars.find_index{|x| x['name'] == name }
    next unless i.nil?
    STDOUT.puts "dev env var #{name.red} defined in #{env_file.red} does not exist in role manifest"
    @has_errors += 1
  end
end

# Checks that none of the role manifest templates are used as constants
def check_non_templates(manifest)
  manifest['configuration']['templates'].each do |property, template|
    empty = Common.parameters_in_template(template).length == 0

    next unless empty
    STDOUT.puts "global role manifest template #{property.red} is used as a constant"
    @has_errors += 1
  end
end

# Checks that all roles required any of the clustering parameters use
# scripts/configure-HA-hosts.sh and that all roles which don't will
# not.
def check_clustering(manifest, bosh_properties)
  # :: hash (release -> hash (job -> hash (property -> default)))

  params = {}
  manifest['configuration']['templates'].each do |property, template|
    params[property] = Common.parameters_in_template(template)
  end

  # Iterate over roles
  # - Iterate over jobs
  #   - Determine templates used by job
  #     - Determine parameters used by template
  #       - Collect /_HCF_CLUSTER_IPS$/

  manifest['roles'].each do |role|
    rparams = params.dup
    if role['configuration'] && role['configuration']['templates']
      role['configuration']['templates'].each do |property, template|
        rparams[property] = Common.parameters_in_template(template)
      end
    end

    collected_params = Hash.new { |h, parameter| h[parameter] = [] }
    # collected_params :: hash (parameter -> array (pair (job,release)))
    # And default unknown elements as empty list.

    (role['jobs'] || []).each do |job|
      job_name = job['name']
      release_name = job['release_name']
      bosh_properties[release_name][job_name].each_key do |property|
        (rparams["properties." + property] || []).each do |param|
          next unless param.end_with? '_HCF_CLUSTER_IPS'
          collected_params[param] << [job_name, release_name]
        end
      end
    end

    if collected_params.empty?
      next unless has_script(role, @configure_ha)
      STDOUT.puts "Superfluous use of #{@configure_ha.red} by role #{role['name'].red}"
      @has_errors += 1
    else
      next if has_script(role, @configure_ha)
      STDOUT.puts "Missing #{@configure_ha.red} in role #{role['name'].red}, requested by"
      collected_params.each do |param, jobs|
        STDOUT.puts "- #{param.red}"
        jobs.each do |job|
          STDOUT.puts "  - Job #{job[0].red} in release #{job[1].red}"
        end
      end
      @has_errors += 1
    end
  end
end

def has_script(r,script)
  (r['environment_scripts'] || []).include? script
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

    next if found
    STDOUT.puts "role manifest variable #{variable['name'].red} was not found in any role manifest template"
    @has_errors += 1
  end
end

def global_variables(manifest)
  variables = {}
  manifest['configuration']['variables'].each do |var|
    variables[var['name']] = nil
  end
  variables
end

# Conversely to the preceding, check if all templates use only declared parameters
def check_rm_templates(templates,manifest,global_variables)
  # Report all templates which contain references to unknown
  # parameters, and the bogus parameters themselves.  We ignore the
  # parameters provided by HCP, and the proxy parts, these are ok.

  templates.each do |label, defs|
    defs.each do |property, template|
      Common.parameters_in_template(template).each do |vname|
        report_bogus_variable("#{label.cyan} template #{property.red}", vname, global_variables)
      end
    end
  end
end

def report_bogus_variable(label,vname,global_variables)
  return if Common.special_env(vname)
  return if Common.special_uaa(vname)
  return if Common.special_indexed(vname)
  return if global_variables.has_key? vname

  STDERR.puts "#{label}: Referencing undeclared variable #{vname.red}"
  @has_errors += 1
end

# Check to see if all properties are defined in a BOSH release
def check_bosh_properties(defs, bosh_properties, check_type)
  # :: hash (release -> hash (job -> hash (property -> default)))

  defs.each do |prop, _|
    next if Common.special_property(prop)
    next unless prop.start_with? 'properties.'

    bosh_property = prop.sub(/^properties./, '')

    next if property_exists_in_bosh?(bosh_property, bosh_properties)
    STDOUT.puts "#{check_type} #{bosh_property.red} was not found in any bosh release"
    @has_errors += 1
  end
end

def property_exists_in_bosh?(property, bosh_properties)
  bosh_properties.any? {|_, jobs|
    jobs.any? {|_, property_hash|
      property_hash.include? property
    }
  }
end

# Convert the nested hash (release -> (job -> (property -> default value)))
# Into a simpler hash     (property -> (default -> [[release,job]...])
# In essence the incoming data is inverted and rekeyed to the property
# and default values.
def global_defaults(bosh_properties)
  props = Hash.new do |props, property|
    props[property] = Hash.new do |prop_hash, default|
      prop_hash[default] = []
    end
  end

  bosh_properties.each do |release, jobs|
    jobs.each do |job, property_hash|
      property_hash.each do |property, default|
        props[property][default] << [release, job]
      end
    end
  end

  props
end

# Similar to global_defaults, the inversion is only partial,
# collecting the jobs under properties and defaults, but keeping this
# per-release, not mixing the releases together.
# Result is (release -> (property -> (default -> [job...]))
def release_defaults(bosh_properties)
  props = Hash.new do |props, release|
    props[release] = Hash.new do |release_hash, property|
      release_hash[property] = Hash.new do |property_hash, default|
        property_hash[default] = []
      end
    end
  end

  bosh_properties.each do |release, jobs|
    jobs.each do |job, property_hash|
      property_hash.each do |property, default|
        props[release][property][default] << job
      end
    end
  end

  props
end

# Check that all bosh properties have the same default across all the
# loaded releases and their jobs.
def check_bosh_defaults(global_defaults)
  prefix = "Warning"

  global_defaults.each do |property, defaults|
    # Ignore properties with a single default across all definitions.
    next if defaults.size == 1
    @has_warnings += 1

    maxlen = 0
    defaults.each { |default, _ | maxlen = [maxlen, stringify(default).length].max }

    STDOUT.puts "#{prefix.bgyellow}: Property #{property.yellow} has #{defaults.size.to_s.yellow} defaults:"
    defaults.each do |default, jobs|
      default = stringify(default)

      if jobs.length == 1
        release, job = jobs[0]
        STDOUT.puts "- Default #{default.ljust(maxlen).cyan}: Release #{release.cyan}, job #{job.cyan}"
      else
        STDOUT.puts "- Default #{default.cyan}:"
        jobs.each do |spec|
          release, job = spec
          STDOUT.puts "  - Release #{release.cyan}, job #{job.cyan}"
        end
      end
    end
  end
end

def stringify(x)
  # Distinguish null/nil from empty string
  case true
  when x.nil? then '((NULL))'
  when x.to_s.empty? then '""'
  else x.to_s
  end
end

# Check to see if all opinions differ from their defaults in the BOSH releases.
# Note, if a property has more than one default the opinion automatically differs
# from at least one.

def check_light_defaults(defs, global_defaults)
  # global_defaults :: (property -> (default -> [[release,job]...]))

  defs.each do |prop, opinion|
    # Ignore specials
    next if Common.special_property(prop)
    # Ignore more specials
    next unless prop.start_with? 'properties.'
    prop = prop.sub(/^properties./, '')
    # Ignore unknown/undefined
    next unless global_defaults.include? prop
    # Ignore if default is not unambigous
    if global_defaults[prop].size > 1
      STDOUT.puts "light opinion #{prop.yellow} ignored, #{"ambiguous default".yellow}"
      next
    end

    # Get the unambigous default
    default = global_defaults[prop].keys[0]

    next unless opinion == default

    # Ok, the opinion matches an unambigous default in the releases.
    # That is noteworthy.

    STDOUT.puts "light opinion #{prop.red} matches default of #{stringify(opinion).red}"
    @has_errors += 1
  end
end

def dark_exposed(templates, dark)
  # Everything in dark must have a definition in the
  # role-manifest, i.e. be exposed to the user
  dark.each do |k,v|
    next if contains(templates,k)
    STDOUT.puts "dark-opinion #{k.red} missing template in role-manifest"
    @has_errors += 1
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
    @has_errors += 1
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
      @has_errors += 1
      sep = true
    end
  end

  STDOUT.puts "" if sep

  defs.each do |property, value|
    next unless light[property]
    if value.to_s != light[property].to_s
      @has_errors += 1
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
