## HCP output provider
# # ## ### ##### ########

# Put file's location into the load path. Mustache does not use 'require_relative'
$:.unshift File.dirname(__FILE__)

require 'common'
require 'set'

# Provider for HCP specifications derived from a role-manifest.
class ToHCP < Common
  def initialize(options)
    super(options)
    # In HCP the version number becomes a kubernetes label, which puts
    # some restrictions on the set of allowed characters and its
    # length.
    @hcf_version.gsub!(/[^a-zA-Z0-9.-]/, '-')
    @hcf_version = @hcf_version.slice(0,63)

    @hcp_cpu_num = @options[:hcp_cpu_num]

    @property = convert_properties(@options[:propmap])

    # And the map (component -> list(parameter-name)).
    # This is created in "determine_component_parameters" (if @property)
    # and used by "component_parameters" (if @component_parameters)
    @component_parameters = nil
  end

  # Public API
  def transform(role_manifest)
    JSON.pretty_generate(to_hcp(role_manifest))
  end

  # Internal definitions

  def to_hcp(role_manifest)
    definition = empty_hcp

    fs = definition['volumes']
    save_shared_filesystems(fs, collect_shared_filesystems(role_manifest['roles']))

    if role_manifest['configuration'] && role_manifest['configuration']['variables']
      sdl_names = sdl_names(role_manifest['configuration']['variables'])
    else
      sdl_names = {}
    end

    collect_global_parameters(role_manifest, sdl_names, definition)
    determine_cpu_unit(role_manifest)
    determine_component_parameters(role_manifest, sdl_names)
    process_roles(role_manifest, definition, fs, sdl_names)

    definition
    # Generated structure
    ##
    # DEF.name						/string
    # DEF.sdl_version					/string
    # DEF.vendor					/string
    # DEF.preflight[].					(*9)
    # DEF.postflight[].					(*9)
    # DEF.volumes[].name				/string
    # DEF.volumes[].size_gb				/int32
    # DEF.volumes[].filesystem				/string (*2)
    # DEF.volumes[].shared				/bool
    # DEF.components[].name				/string
    # DEF.components[].image				/string	(*7)
    # DEF.components[].min_RAM_mb			/int32
    # DEF.components[].min_VCPU				/int32
    # DEF.components[].platform				/string	(*3)
    # DEF.components[].capabilities[]			/string (*1)
    # DEF.components[].workload_type			/string (*4)
    # DEF.components[].entrypoint[]			/string (*5)
    # DEF.components[].min_instances			/int
    # DEF.components[].max_instances			/int
    # DEF.components[].service_ports[].name		/string
    # DEF.components[].service_ports[].protocol		/string	('TCP', 'UDP')
    # DEF.components[].service_ports[].source_port	/int32
    # DEF.components[].service_ports[].target_port	/int32
    # DEF.components[].service_ports[].public		/bool
    # DEF.components[].volume_mounts[].volume_name	/string
    # DEF.components[].volume_mounts[].mountpoint	/string
    # DEF.components[].parameters[].name		/string
    # DEF.parameters[].name				/string
    # DEF.parameters[].description			/string, !empty
    # DEF.parameters[].default				/string
    # DEF.parameters[].example				/string, !empty
    # DEF.parameters[].immutable			/bool
    # DEF.parameters[].required				/bool
    # DEF.parameters[].secret				/bool
    # DEF.features.auth[].auth_zone			/string
    #
    # (*1) Too many to list here. See hcp-developer/service_models.md
    #      for the full list. Notables:
    #      - ALL
    #      - NET_ADMIN
    #      Note further, NET_RAW accepted, but not supported.
    #
    # (*2) ('ext4', 'xfs', 'ntfs' (platform-dependent))
    # (*3) ('linux-x86_64', 'win2012r2-x86_64')
    # (*4) ('container', 'vm')
    # (*5) (cmd and parameters, each a separate entry)
    # (*7) Container image name for component
    # (*8) See the 1st 3 attributes of components
    # (*9) Subset of comp below (+ retry_count /int32)
  end

  def empty_hcp
    {
      'name'              => 'hcf',         # TODO: Specify via option?
      'sdl_version'       => @hcf_version,
      'product_version'   => product_version,
      'vendor'            => 'HPE',         # TODO: Specify via option?
      'volumes'           => [],            # We do not generate volumes, leave empty
      'components'        => [],            # Fill from the roles, see below
      'features'          => {},            # Fill from the roles, see below
      'parameters'        => [],            # Fill from the roles, see below
      'preflight'         => [],            # Fill from the roles, see below
      'postflight'        => []             # Fill from the roles, see below
    }
  end

  def process_roles(role_manifest, definition, fs, sdl_names)
    section_map = {
      'pre-flight'  => 'preflight',
      'flight'      => 'components',
      'post-flight' => 'postflight'
    }
    gparam = definition['parameters']
    role_manifest['roles'].each do |role|
      # HCP doesn't have manual jobs
      next if flight_stage_of(role) == 'manual'
      next if tags_of(role).include?('dev-only')

      # We don't run to infinity because we will flood HCP if we do
      retries = task?(role) ? 5 : 0
      dst = definition[section_map[flight_stage_of(role)]]
      add_role(role_manifest, fs, dst, role, retries, sdl_names)

      # Collect per-role parameters
      if role['configuration'] && role['configuration']['variables']
        collect_parameters(gparam, sdl_names, role['configuration']['variables'])
      end
    end
    if role_manifest['auth']
      definition['features']['auth'] = [generate_auth_definition(role_manifest)]
    end
  end

  def collect_global_parameters(role_manifest, sdl_names, definition)
    p = definition['parameters']
    if role_manifest['configuration'] && role_manifest['configuration']['variables']
      collect_parameters(p, sdl_names, role_manifest['configuration']['variables'])
    end
  end

  def collect_shared_filesystems(roles)
    shared = {}
    roles.each do |role|
      runtime = role['run']
      next unless runtime && runtime['shared-volumes']

      runtime['shared-volumes'].each do |v|
        add_shared_fs(shared, v)
      end
    end
    shared
  end

  def add_shared_fs(shared, v)
    vname = v['tag']
    vsize = v['size']
    abort_on_mismatch(shared, vname, vsize)
    shared[vname] = vsize
  end

  def abort_on_mismatch(shared, vname, vsize)
    if shared[vname] && vsize != shared[vname]
      # Raise error about definition mismatch
      raise 'Size mismatch for shared volume "' + vname + '": ' +
            vsize + ', previously ' + shared[vname]
    end
  end

  def save_shared_filesystems(fs, shared)
    shared.each do |vname, vsize|
      add_filesystem(fs, vname, vsize, true)
    end
  end

  def add_filesystem(fs, name, size, shared)
    the_fs = {
      'name'       => name,
      'size_gb'    => size,
      'filesystem' => 'ext4',
      'shared'     => shared
    }
    fs.push(the_fs)
  end

  def add_role(role_manifest, fs, comps, role, retrycount, sdl_names)
    bname = role['name']
    iname = "#{@hcf_prefix}-#{bname}"

    runtime = role['run']
    scaling = runtime['scaling']
    min     = scaling['min']
    max     = scaling['max']

    the_comp = {
      'name'          => bname,
      'repository'    => @dtr,
      'organization'  => @dtr_org,
      'image'         => iname,
      'tag'           => @hcf_tag,
      'min_RAM_mb'    => runtime['memory'],
      'min_VCPU'      => cpu_fraction(runtime['virtual-cpus']),
      'platform'      => 'linux-x86_64',
      'capabilities'  => runtime['capabilities'],
      'min_instances' => min,     # See above for the calculation for the
      'max_instances' => max,     # component and its clones.
      'service_ports' => [],	  # Fill from role runtime config, see below
      'volume_mounts' => [],	  # Ditto
      'parameters'    => [],	  # Fill from role configuration, see below
      'workload_type' => 'container'
    }

    the_comp['retry_count'] = retrycount if retrycount > 0

    # Record persistent and shared volumes, ports
    pv = runtime['persistent-volumes']
    sv = runtime['shared-volumes']

    add_volumes(fs, the_comp, pv, false) if pv
    add_volumes(fs, the_comp, sv, true) if sv

    add_ports(the_comp, runtime['exposed-ports']) if runtime['exposed-ports']

    # Reference global parameters
    if role_manifest['configuration'] && role_manifest['configuration']['variables']
      add_parameter_names(the_comp,
                          component_parameters(the_comp, sdl_names.values))
    end

    # Reference per-role parameters
    if role['configuration'] && role['configuration']['variables']
      add_parameters(the_comp, role['configuration']['variables'])
    end

    # Reference explicitly declared parameters. This is exclusive to
    # docker roles, as they have no bosh parameters.
    if (role['type'] == 'docker') && runtime['env']
      add_parameters(the_comp,
                     runtime['env'].collect { |name| { 'name' => name } })
    end

    # TODO: Should check that the intersection of between global and
    # role parameters is empty.

    comps.push(the_comp)
  end

  def sdl_names(variables)
    map = {}
    variables.each do |var|
      vname   = var['name']
      vsecret = var.has_key?("secret") ? var['secret'] : false

      # secrets currently need to be lowercase and can only use dashes, not underscores
      # This should be handled by HCP instead: https://jira.hpcloud.net/browse/CAPS-184
      vname = vname.downcase.gsub('_', '-') if vsecret

      map[var['name']] = vname
    end
    map
  end

  def add_volumes(fs, component, volumes, shared_fs)
    vols = component['volume_mounts']
    serial = 0
    volumes.each do |v|
      serial, the_vol = convert_volume(fs, v, serial, shared_fs)
      vols.push(the_vol)
    end
  end

  def convert_volume(fs, v, serial, shared_fs)
    vname = v['tag']
    if !shared_fs
      # Private volume, export now
      vsize = v['size'] # [GB], same as used by HCP, no conversion required
      serial += 1

      add_filesystem(fs, vname, vsize, false)
    end

    [serial, a_volume_spec(vname, v['path'])]
  end

  def a_volume_spec(name, path)
    {
      'volume_name' => name,
      'mountpoint'  => path
    }
  end

  MAX_EXTERNAL_PORT_COUNT = 10
  EXTERNAL_PORT_UPPER_BOUND = 29999
  def add_ports(component, ports)
    cname = component['name']
    cports = component['service_ports']
    ports.each do |port|
      if port['external'].to_s.include? '-'
        # HCP does not yet support port ranges; do what we can. CAPS-435
        if port['external'] != port['internal']
          raise "Port range forwarding #{port['name']}: must have the same external / internal ranges"
        end
        first, last = port['external'].split('-').map(&:to_i)
        (first..last).each do |port_number|
          cports.push(convert_port(cname, port.merge(
            'external' => port_number,
            'internal' => port_number,
            'name'   => "#{port['name']}-#{port_number}"
          )))
        end
      else
        cports.push(convert_port(cname, port))
      end
    end
    if cports.length > MAX_EXTERNAL_PORT_COUNT
      raise "Error: too many ports to forward (#{cports.length}) in #{cname}, limited to #{MAX_EXTERNAL_PORT_COUNT}"
    end
  end

  def convert_port(cname, port)
    name = port['name']
    if port['external'] > EXTERNAL_PORT_UPPER_BOUND
      raise "Error: Cannot export port #{port['external']} (in #{cname}), above the limit of #{EXTERNAL_PORT_UPPER_BOUND}"
    end
    if name.length > 15
      # Service ports must have a length no more than 15 characters
      # (to be a valid host name)
      name = "#{name[0...8]}#{name.hash.to_s(16)[-8...-1]}"
    end
    {
      'name'        => name,
      'protocol'    => port['protocol'],
      'source_port' => port['external'],
      'target_port' => port['internal'],
      'public'      => port['public']
    }
  end

  def collect_parameters(para, sdl_names, variables)
    variables.each do |var|
      para.push(convert_parameter(var, sdl_names))
    end
  end

  def process_templates(rolemanifest, role)
    return unless rolemanifest['configuration'] && rolemanifest['configuration']['templates']

    templates = {}
    rolemanifest['configuration']['templates'].each do |property, template|
      templates[property] = Common.parameters_in_template(template).reject do |pname|
        Common.special_env(pname)
      end
    end

    if role['configuration'] && role['configuration']['templates']
      role['configuration']['templates'].each do |property, template|
        templates[property] = Common.parameters_in_template(template).reject do |pname|
          Common.special_env(pname)
        end
      end
    end

    templates
  end

  def determine_component_parameters(role_manifest, sdl_names)
    # Here we compute the per-component parameter information.
    # Incoming data are:
    # 1. role-manifest :: (role/component -> (job,release))
    # 2. @property     :: (release -> job -> list(property))
    # 3. template      :: (property -> list(parameter-name))
    #
    # Iterating and indexing through these we generate
    #
    # =  @component_parameters :: (role -> list(parameter-name))

    return unless @property

    @component_parameters = {}
    role_manifest['roles'].each do |role|
      templates = process_templates(role_manifest, role)
      next unless templates

      env_var_names = Set.new
      if role['jobs']
        role['jobs'].each do |job|
          release = job['release_name']
          unless @property[release]
            STDERR.puts "Role #{role['name']}: Reference to unknown release #{release}"
            next
          end

          jname = job['name']
          unless @property[release][jname]
            STDERR.puts "Role #{role['name']}: Reference to unknown job #{jname} @#{release}"
            next
          end

          @property[release][jname].each do |pname|
            # Note. '@property' uses property names without a
            # 'properties.' prefix as keys, whereas the
            # template-derived 'templates' has this prefix.
            pname = "properties.#{pname}"

            # Ignore the job/release properties not declared as a
            # template. These are used with their defaults, or our
            # opinions. They cannot change and have no parameters.
            next unless templates[pname]

            env_var_names += templates[pname]
          end
        end
      end

      env_var_names += ['HCF_LOG_PROTOCOL', 'HCF_LOG_HOST', 'HCF_LOG_PORT']

      # At this point, `env_var_names` is the list of all environment variables
      # that are used in the role.  Some of them, such as `UAA_CLIENTS`, may
      # not actually come from the SDL; we need to reject those.  We also need
      # to convert them via the sdl_names mapping, as the secrets are named
      # differently (lower-case-with-dash vs UPPER_CASE_UNDERSCORE).
      component_param_names = env_var_names.map { |name| sdl_names[name] }
      component_param_names.reject!(&:nil?)
      @component_parameters[role['name']] = component_param_names.sort
    end
  end

  def component_parameters(component, variables)
    return @component_parameters[component['name']] if @component_parameters
    # If we have no per-component information we fall back to use all
    # declared parameters.
    variables
  end

  def add_parameters(component, variables)
    para = component['parameters']
    variables.each do |var|
      para.push(convert_parameter_ref(var))
    end
  end

  def add_parameter_names(component, varnames)
    para = component['parameters']
    varnames.each do |vname|
      para.push(convert_parameter_name(vname))
    end
  end

  def convert_parameter(var, sdl_names)
    vname     = var['name']
    vrequired = var.has_key?("required") ? var['required'] : true
    vsecret   = var.has_key?("secret") ? var['secret'] : false
    vexample  = (var['example'] || var['default']).to_s
    vexample  = 'unknown' if vexample == ''
    vdescription = var["description"].to_s

    vname = sdl_names[vname]

    parameter = {
      'name'        => vname,
      'description' => vdescription,
      'example'     => vexample,
      'required'    => vrequired,
      'secret'      => vsecret,
    }

    default_value = (var['default'].nil? || vsecret) ? nil : var['default'].to_s
    unless default_value.nil?
      parameter['default'] = default_value
    end

    unless var['generator'].nil?
      parameter['generator'] = convert_parameter_generator(var, vname)
    end

    unless var['immutable'].nil?
      parameter['immutable'] = var['immutable']
    end

    return parameter
  end

  def convert_parameter_generator(var, vname)
    optional_keys = ['value_type', 'length', 'characters', 'key_length']
    generator_input = var['generator']
    generate = generator_input.select { |k| optional_keys.include? k }
    generate['type'] = generator_input['type']
    if generator_input.has_key?('subject_alt_names')
      optional_san_keys = ['static', 'parameter', 'wildcard']
      generate['subject_alt_names'] = generator_input['subject_alt_names'].map do |subj_alt_name|
        subj_alt_name.select { |k| optional_san_keys.include? k }
      end
    end

    return {
      'id'        => generator_input['id'] || vname,
      'generate'  => generate
    }
  end

  def convert_parameter_ref(var)
    {
      'name' => var['name']
    }
  end

  def convert_parameter_name(vname)
    {
      'name' => vname
    }
  end

  def determine_cpu_unit(role_manifest)
    # I. Sum the number of virtual-cpus requested by the components.
    #    Manual and dev-only components are excluded, as HCP does not
    #    have these, see "process_roles".
    # Note, we do count the bosh-tasks, i.e. post-flight roles.
    # Fitting them in simply gives us a bit more room later, when they
    # are done.
    total = 0
    count = 0
    role_manifest['roles'].each do |role|
      next if flight_stage_of(role) == 'manual'
      next if tags_of(role).include?('dev-only')
      runtime = role['run']
      next unless runtime
      next unless runtime['virtual-cpus']

      total += runtime['virtual-cpus']
      count += 1

      #STDERR.puts "#{role['name']}: #{runtime['virtual-cpus']}  --> #{total}"
    end

    # II. Compute the base unit, comparing the number of actual cpus
    #     we wish to fit into vs the requested number.
    @hcp_cpu_unit = @hcp_cpu_num.fdiv(total)

    STDERR.puts "CPUs: Requested:  #{total}, over #{count} roles"
    STDERR.puts "      Fit into:   #{@hcp_cpu_num}"
    STDERR.puts "      Unit slice: #{@hcp_cpu_unit}"
  end

  def cpu_fraction(n)
    n * @hcp_cpu_unit
  end

  def scale_min(x,indexed,mini,maxi)
    last = [mini,indexed].min-1
    if x < last
      1
    elsif x == last
      mini-x
    else
      0
    end
  end

  def scale_max(x,indexed,mini,maxi)
    last = indexed-1
    if x < last
      1
    else
      maxi-x
    end
  end

  # Generate the features.auth element
  def generate_auth_definition(role_manifest)
    properties = role_manifest['configuration']['templates']
    auth_configs = role_manifest['auth']
    {
      auth_zone: 'self',
      user_authorities: auth_configs['authorities'],
      clients: auth_configs['clients'].map{|client_id, client_config|
        config = {
          id: client_id,
          authorized_grant_types: client_config['authorized-grant-types'],
          scopes: client_config['scope'] || [],
          autoapprove: client_config['autoapprove'] || [],
          authorities: client_config['authorities'],
          access_token_validity: client_config['access-token-validity'],
          refresh_token_validity: client_config['refresh-token-validity'],
          parameters: []
        }

        config.delete_if { |_, value| value.nil? }

        [:authorized_grant_types, :scopes, :authorities].each do |key|
          if config[key].is_a? String
            # For these values, HCP wants them as arrays,
            # UAA wants comma-delimited strings
            config[key] = config[key].split(',')
          end
        end

        if config[:autoapprove].eql? true
          # UAA.yml's `true` means approve everything
          config[:autoapprove] = config[:scopes].dup
        end

        if config[:authorized_grant_types].nil?
          # While UAA.yml accepts things with no grant types, the UAA API
          # requires them.  Push in the defaults.
          config[:authorized_grant_types] = ['authorization_code', 'refresh_token']
        end

        secret_value = properties["properties.uaa.clients.#{client_id}.secret"]
        unless secret_value.nil?
          # We need to get rid of some of the nested layers of mustaching
          secret_value.gsub!(/^(["'])(.*)\1$/, '\2')
          secret_value.gsub!(/\(\((.*?)\)\)/, '\1')
          # secrets currently need to be lowercase and can only use dashes, not underscores
          # This should be handled by HCP instead: https://jira.hpcloud.net/browse/CAPS-184
          secret_value.downcase!.gsub!('_', '-')
          config[:parameters] << { name: secret_value }
        end
        config
      }
    }
  end

  # # ## ### ##### ########
end

# # ## ### ##### ########
