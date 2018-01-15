# -*- coding: utf-8 -*-
## Common functionality for all providers.
# # ## ### ##### ########
require 'mustache'

# Colorization support.
class String
  def red
    "\033[0;31m#{self}\033[0m"
  end

  def green
    "\033[0;32m#{self}\033[0m"
  end

  def yellow
    "\033[0;33m#{self}\033[0m"
  end

  def blue
    "\033[0;34m#{self}\033[0m"
  end

  def magenta
    "\033[0;35m#{self}\033[0m"
  end

  def cyan
    "\033[0;36m#{self}\033[0m"
  end
end

# Common functionality for all providers.
class Common
  # # ## ### ##### ########
  ## Common status (options and derived DTR information)

  def initialize(options)
    @options = options
    initialize_dtr_information
  end

  def convert_properties(map)
    # Quick access to the loaded properties: (release -> job -> property -> default-value)
    # For the filtering we need:             (release -> job -> list(property))
    property = Hash.new do |props, release|
      props[release] = Hash.new do |release_hash, job|
        release_hash[job] = []
      end
    end

    map.each do |release, jobs|
      jobs.each do |job, properties|
        properties.each_key do |property_name|
          property[release][job] << property_name
        end
      end
    end

    property
  end

  def initialize_dtr_information
    # Get options, set defaults for missing parts
    @dtr          = @options[:dtr]
    @dtr_org      = @options[:dtr_org]
    @scf_tag      = @options[:scf_tag]
    @scf_prefix   = @options[:scf_prefix]
    @scf_version  = @options[:scf_version]
    @scf_root_dir = @options[:scf_root_dir]
  end

  # # ## ### ##### ########
  ## Predicates on roles.

  def typeof(role)
    role['type'] || 'bosh'
  end

  def flight_stage_of(role)
    role['run']['flight-stage'] || 'flight'
  end

  def tags_of(role)
    role['tags'] || []
  end

  def skip_manual?(role)
    flight_stage_of(role) == 'manual' && !@options[:manual]
  end

  def job?(role)
    flight_stage_of(role) == 'flight'
  end

  def task?(role)
    !job?(role)
  end

  # # ## ### ##### ########
  def self.collect_dev_env(env_files)
    collected_env = {}

    env_files.each do |env_file|
      File.readlines(env_file, encoding:'UTF-8').each_with_index do |line, i|
        line.strip!
        next if line.empty? || line.start_with?('#')
        name, value = line.split('=', 2)
        if value.nil?
          match = /^ \s* unset \s+ (?<name>\w+) \s* $/x.match(line)
          if match
            collected_env.delete match['name']
          else
            STDERR.puts "Cannot parse line #{i} in #{env_file}: #{line}"
            exit 1
          end
        else
          collected_env[name] = [env_file, value]
        end
      end
    end

    collected_env
  end

  def self.load_role_manifest(path)
    if path == '-'
      # Read from stdin.
      role_manifest = YAML.load($stdin)
    else
      role_manifest = YAML.load_file(path)
    end

    role_manifest
  end

  def self.parameters_in_template(template)
    # Note: The prefix "{{=(( ))=}}" is required because role manifest
    # uses ((, )) as delimiters by default, which is non-default for
    # mustache. The prefix activates our delimiters.

    template = template.to_s
    tokens = Mustache::Template.new("{{=(( ))=}}" + template).tokens

    vars = []
    vars_in_tokens(vars, tokens)
    vars.uniq
  end

  def self.vars_in_tokens(vars, tokens)
    tokens.each do |atoken|
      # Skip :multi
      next unless atoken.kind_of?(Array)

      # Skip static and other non-mustache things
      next unless atoken[0] == :mustache

      # Now we know that we are looking at a ((...)) form.  All of
      # them have the primary variable(s) at the same place. Take and
      # remember them.
      vars.push(*atoken[2][2])
      next if atoken[1] == :etag

      # We are now looking at the more complex forms ((#...), ((^...),
      # and ((/...).  These all have a nested set of tokens we have to
      # process as well.
      vars_in_tokens(vars, atoken[4])
    end
  end

  def self.special_property(key)
    # Detect keys with structured values "collect" must not recurse into.
    return true if key =~ /^properties.cc.security_group_definitions/
    return true if key =~ /^properties.cc.diego.lifecycle_bundles/
    return true if key =~ /^properties.ccdb.roles/
    return true if key =~ /^properties.uaadb.roles/
    return true if key =~ /^properties.uaa.clients/
    return true if key =~ /^properties.uaa.jwt.policy.keys/
    return true if key =~ /^properties.cc.quota_definitions/
    false
  end

  def self.special_indexed(key)
    return true if key == "SCF_BOOTSTRAP"
    return true if key == "SCF_ROLE_INDEX"
    false
  end

  def self.special_uaa(key)
    return true if key == "JWT_SIGNING_PUB"
    return true if key == "JWT_SIGNING_PEM"
    return true if key == "UAA_CLIENTS"
    return true if key == "UAA_USER_AUTHORITIES"
    false
  end

  def self.special_env(key)
    # Detect env var keys that are special (they are used, but not defined in the role manifest).
    return true if key.start_with? 'SCF_'
    %w(
      CATS_SUITES
      CONSUL_LOG_LEVEL
      DNS_RECORD_NAME
      GO_LOG_LEVEL
      IP_ADDRESS
      JWT_SIGNING_PEM
      JWT_SIGNING_PUB
      NGINX_LOG_LEVEL
    ).include? key
  end

  def self.special_use(key)
    # Detect env var keys that are special (they are defined, but not
    # used in the role-manifest. They are needed and used in scripts).
    %w(
      SCF_LOG_HOST
      SCF_LOG_PORT
      SCF_LOG_PROTOCOL
    ).include? key
  end

  def product_version
    return @product_version if @product_version
    product_version = open("#{@scf_root_dir}/VERSION").read.strip
    @product_version = "#{product_version}"
  end
end
