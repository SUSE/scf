#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
## ### ##### ########
# Tool to check role-manifest.yml, opinions.yml, dark-opinions.yml for inconsistencies.

#require 'optparse'
require 'yaml'
require 'json'
require 'pathname'
require_relative 'vagrant-setup/common'

DEFAULT_CONFIG_PATH = File.join(File.dirname(__FILE__), '../container-host-files/etc/scf/config/')

def main
  STDOUT.sync = true
  @has_errors = 0
  @has_warnings = 0
  @configure_ha = "scripts/configure-HA-hosts.sh"

  STDOUT.puts "Running configuration checks ..."

  bosh_properties = YAML.load(ARGF.read)
  # :: hash (release -> hash (job -> hash (property -> default)))

  manifest_file = ENV.fetch('FISSILE_ROLE_MANIFEST', File.expand_path(File.join(DEFAULT_CONFIG_PATH, 'role-manifest.yml')))
  light_opinions_file = ENV.fetch('FISSILE_LIGHT_OPINIONS', File.expand_path(File.join(DEFAULT_CONFIG_PATH, 'opinions.yml')))
  dark_opinions_file = ENV.fetch('FISSILE_DARK_OPINIONS', File.expand_path(File.join(DEFAULT_CONFIG_PATH, 'dark-opinions.yml')))

  manifest = Common.load_role_manifest(manifest_file)
  light = YAML.load_file(light_opinions_file)
  dark = YAML.load_file(dark_opinions_file)

  light = flatten(light)
  dark = flatten(dark)

  templates = {}
  if manifest['configuration'] && manifest['configuration']['templates']
    templates['__global__'] = manifest['configuration']['templates']
  end
  manifest['instance_groups'].each do |r|
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
    check_overridden_opinions(defs, light, label == '__global__')
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
  # Try a few ways to find the env dir
  env_dir = %w(../../../../bin/settings env).
    map { |relpath| File.join(File.dirname(manifest_file), relpath) }.
    find { |path| Dir.exist? path }

  if env_dir.nil?
    STDOUT.puts "\nFailed to find environment directory".red
    @has_errors += 1
    dev_env = {}
  else
    all_env_files = Dir.glob(File.join(env_dir, "**/*.env"))
    dev_env = Common.collect_dev_env(all_env_files)
  end
  check_env_files(manifest, dev_env)

  STDOUT.puts "\nAll role manifest params must be used".cyan
  check_rm_variables(manifest)

  STDOUT.puts "\nAll role manifest params must be sorted".cyan
  check_sort manifest['configuration']['variables'].map { |v| v['name'] }, "variables"

  STDOUT.puts "\nAll role manifest templates must use only declared params".cyan
  check_rm_templates(templates, manifest, global_variables)

  STDOUT.puts "\nAll role manifest templates must be sorted".cyan
  check_sort manifest['configuration']['templates'], 'global templates'
  templates.each_pair do |scope, template|
    check_sort template, "#{scope} templates" unless scope == '__global__'
  end

  STDOUT.puts "\nThe role manifest must not contain any constants in the global section".cyan
  check_non_templates(manifest)

  STDOUT.puts "\nAll of the scripts must be used".cyan
  check_role_manifest_scripts(manifest, manifest_file)

  STDOUT.puts "\nCheck clustering".cyan
  check_clustering(manifest, bosh_properties)

  STDOUT.puts "\nAll BOSH roles must forward syslog".cyan
  check_roles_forward_syslog(manifest)

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
  role_count = manifest['instance_groups'].length
  bosh_properties_count = bosh_properties.inject([]) do |all_props, (_, jobs)|
    jobs.inject(all_props) do |all_props, (_, properties)|
      all_props << properties
    end
  end.flatten.uniq.length
  template_count = templates.inject([]) do |all_templates, (_, template_list)|
    all_templates << template_list.keys
  end.flatten.length
  scripts_dir = File.expand_path(File.join(__FILE__, '../../container-host-files/etc/scf/config/scripts'))
  scripts = Dir.glob(File.join(scripts_dir, "**/*")).reject { |fn| File.directory?(fn) }
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
  # proxy parts, these are ok.

  manifest['instance_groups'].each do |role|
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
  manifest['instance_groups'].each do |role|
    next if role['type'] == 'docker'
    next unless role['run']
    next unless role['run']['env']

    STDOUT.puts "Non-docker role #{role['name'].red} declares bogus parameters (run.env)"
    @has_errors += 1
  end
end

# Makes sure that all scripts are being used in the role manifest
def check_role_manifest_scripts(manifest, manifest_file)
  manifest_dir = File.dirname(manifest_file)
  scripts_dir = File.expand_path(File.join(manifest_dir, 'scripts'))

  scripts = Dir.glob(File.join(scripts_dir, "**/*")).reject { |fn| File.directory?(fn) }
  if scripts.empty?
    STDOUT.puts "#{"Warning".yellow}: No scripts found in #{scripts_dir.yellow}"
    @has_warnings += 1
  end

  scripts.each do |script|
    relative_path = Pathname.new(script).relative_path_from(Pathname.new(manifest_dir))

    found = manifest['instance_groups'].any? do |r|
      (r['scripts'] || []).concat(r['post_config_scripts'] || []).concat(r['environment_scripts'] || []).include?(relative_path.to_s)
    end

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
    i = vars.find_index{ |x| x['name'] == name }
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
  #       - Collect /_CLUSTER_IPS$/

  manifest['instance_groups'].each do |role|
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
      release_name = job['release']
      unless bosh_properties.has_key? release_name
        STDOUT.puts "Role #{role['name']} has job #{job_name} from unknown release #{release_name}"
      end
      unless bosh_properties[release_name].has_key? job_name
        STDOUT.puts "Role #{role['name']} has job #{job_name} not in release #{release_name}"
        @has_errors += 1
        next
      end
      bosh_properties[release_name][job_name].each_key do |property|
        (rparams["properties." + property] || []).each do |param|
          next unless /^(KUBERNETES_CLUSTER_DOMAIN|KUBE_.*_CLUSTER_IPS)$/ =~ param
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
      # secrets-generation uses KUBERNETES_CLUSTER_DOMAIN for cert generation but is not an HA role itself
      next if role['name'] == 'secret-generation'
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

# Checks that all BOSH roles have the syslog forwarding script
def check_roles_forward_syslog(manifest)
  manifest['instance_groups'].each do |role|
    next unless role.fetch('type', 'bosh').downcase == 'bosh'
    next if role.fetch('scripts', []).include? 'scripts/forward_logfiles.sh'
    STDOUT.puts "role #{role['name'].red} does not include forward_logfiles.sh"
    @has_errors += 1
  end
end

# Checks if all role manifest params are being used in a template
def check_rm_variables(manifest)
  templates = manifest['configuration']['templates'].values

  manifest['instance_groups'].each do |r|
    next unless r['configuration']
    next unless r['configuration']['templates']
    templates << r['configuration']['templates'].values
  end

  manifest['configuration']['variables'].each do |variable|
    # "internal" variables are defined but not used in the role manifest. They are referenced directly in scripts.
    next if variable['internal']
    found = templates.any? do |template|
      Common.parameters_in_template(template).include?(variable['name'])
    end

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
  # proxy parts, these are ok.

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
  bosh_properties.any? do |_, jobs|
    jobs.any? do |_, property_hash|
      property_hash.include? property
    end
  end
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
  global_defaults.each do |property, defaults|
    # Ignore properties with a single default across all definitions.
    next if defaults.size == 1
    @has_warnings += 1

    maxlen = defaults.keys.map { |default| stringify(default).length }.max

    STDOUT.puts "#{"Warning".yellow}: Property #{property.yellow} has #{defaults.size.to_s.yellow} defaults:"
    defaults.each do |default, jobs|
      default = stringify(default)

      if jobs.length == 1
        release, job = jobs.first
        STDOUT.puts "- Default #{default.ljust(maxlen).cyan}: Release #{release.cyan}, job #{job.cyan}"
      else
        STDOUT.puts "- Default #{default.cyan}:"
        jobs.each do |(release, job)|
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

def check_overridden_opinions(defs, light, check_conflicts)
  # Templates in the role manifest should not have anything in the opinions.
  # If the values are identical it should just be in opinions.
  # If they are different, then the opinions are superflous.

  duplicates = []
  conflicts = []

  defs.sort.each do |property, value|
    next unless light[property]
    if value.to_s == light[property].to_s
      duplicates << property
    elsif check_conflicts
      conflicts << property
    end
  end

  duplicates.each do |property|
    STDOUT.puts "duplicated #{property.red}"
    @has_errors += 1
  end

  STDOUT.puts "" unless duplicates.empty? || conflicts.empty?

  conflicts.each do |property|
    STDOUT.puts "conflict for #{property.red}"
    STDOUT.puts "  manifest: |#{defs[property]}|"
    STDOUT.puts "  opinion:  |#{light[property]}|"
    @has_errors += 1
  end
end

def check_sort(container, scope)
  if container.respond_to? :keys
    container = container.keys
  end
  found_issues = false
  container[0...-1].each_with_index do |key, i|
    next if key < container[i + 1]
    unless found_issues
      found_issues = true
      STDOUT.puts "At scope #{scope.yellow}:"
    end
    STDOUT.puts "  #{key.red} does not sort before #{container[i + 1].red}"
    @has_errors += 1
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
# the_roles.instance_groups[].name				/string
# the_roles.instance_groups[].type				/string (*)
# the_roles.instance_groups[].scripts[]				/string
# the_roles.instance_groups[].jobs[].name			/string
# the_roles.instance_groups[].jobs[].release     		/string
# the_roles.instance_groups[].processes[].name			/string
# the_roles.instance_groups[].configuration.variables[].name	/string
# the_roles.instance_groups[].configuration.variables[].default	/string
# the_roles.instance_groups[].configuration.templates.<any>	/string
# the_roles.instance_groups[].run.capabilities[]		/string
# the_roles.instance_groups[].run.flight-stage			/string (**)
# the_roles.instance_groups[].run.persistent-volumes[].path	/string, mountpoint
# the_roles.instance_groups[].run.persistent-volumes[].size	/float [GB]
# the_roles.instance_groups[].run.shared-volumes[].path		/string, mountpoint
# the_roles.instance_groups[].run.shared-volumes[].size		/float [GB]
# the_roles.instance_groups[].run.shared-volumes[].tag		/string
# the_roles.instance_groups[].run.memory			/float [MB]
# the_roles.instance_groups[].run.virtual-cpus			/int
# the_roles.instance_groups[].run.scaling.indexed		/int
# the_roles.instance_groups[].run.scaling.min			/int
# the_roles.instance_groups[].run.scaling.max			/int
# the_roles.instance_groups[].run.exposed-ports[].name		/string
# the_roles.instance_groups[].run.exposed-ports[].protocol	/string
# the_roles.instance_groups[].run.exposed-ports[].source	/int
# the_roles.instance_groups[].run.exposed-ports[].target	/int
# the_roles.instance_groups[].run.exposed-ports[].public	/bool
# the_roles.instance_groups[].run.hosts.<any>			/string (name -> ip-addr)
# the_roles.configuration.variables[].name		/string
# the_roles.configuration.variables[].default		/string
# the_roles.configuration.variables[].example		/string
# the_roles.configuration.variables[].secret		/bool
# the_roles.configuration.templates.<any>		/string (key -> value)

# (Ad *) Allowed: 'bosh' (default), 'bosh-task', and 'docker'
# (Ad **) Allowed: 'flight' (default), 'pre-flight', 'post-flight', and 'manual'

main
