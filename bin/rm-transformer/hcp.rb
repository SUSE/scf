## HCP output provider
# # ## ### ##### ########

# Put file's location into the load path. Mustache does not use 'require_relative'
$:.unshift File.dirname(__FILE__)

require 'common'

# Provider for HCP specifications derived from a role-manifest.
class ToHCP < Common
  def initialize(options)
    super(options)
    # In HCP the version number becomes a kubernetes label, which puts
    # some restrictions on the set of allowed characters and its
    # length.
    @hcf_version.gsub!(/[^a-zA-Z0-9.-]/, '-')
    @hcf_version = @hcf_version.slice(0,63)

    # Quick access to the loaded properties (release -> job -> list(property-name))
    @property = @options[:propmap]

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
  private

  # Less is better for these values, so VAR_USE_NONE is the initial value, and replaced by anything
  VAR_USE_SIMPLE = 1
  VAR_USE_COMPOUND = 2
  VAR_USE_AS_FIELD = 3
  VAR_USE_NONE = 4

  def to_hcp(role_manifest)
    @properties_for_var_name = {}
    @property_spec_descriptions = {}
    @property_null_block = {"description"=>"", "default" => ""}
    @ptn_match_single_var = /\A (["']?) \(\( (\w+) \)\) \1 \z/x
    @ptn_match_var_as_field = /(["']) (\w+) \1 \s* : \s* (["']?) \(\((\w+)\)\) \3/x
    get_properties_for_var_name(role_manifest)
    collect_property_spec_descriptions
    definition = empty_hcp

    fs = definition['volumes']
    save_shared_filesystems(fs, collect_shared_filesystems(role_manifest['roles']))
    collect_global_parameters(role_manifest, definition)
    determine_component_parameters(role_manifest)
    process_roles(role_manifest, definition, fs)

    definition
    # Generated structure
    ##
    # DEF.name						/string
    # DEF.version					/string
    # DEF.vendor					/string
    # DEF.preflight[].					(*9)
    # DEF.postflight[].					(*9)
    # DEF.volumes[].name				/string
    # DEF.volumes[].size_gb				/int32
    # DEF.volumes[].filesystem				/string (*2)
    # DEF.volumes[].shared				/bool
    # DEF.components[].name				/string
    # DEF.components[].version				/string
    # DEF.components[].vendor				/string
    # DEF.components[].image				/string	(*7)
    # DEF.components[].min_RAM_mb			/int32
    # DEF.components[].min_disk_gb			/int32
    # DEF.components[].min_VCPU				/int32
    # DEF.components[].platform				/string	(*3)
    # DEF.components[].capabilities[]			/string (*1)
    # DEF.components[].workload_type			/string (*4)
    # DEF.components[].entrypoint[]			/string (*5)
    # DEF.components[].depends_on[].name		/string \(*8)
    # DEF.components[].depends_on[].version		/string \
    # DEF.components[].depends_on[].vendor		/string \
    # DEF.components[].affinity[]			/string
    # DEF.components[].labels[]				/string
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
      'product_version'   => Common.product_version,
      'vendor'            => 'HPE',         # TODO: Specify via option?
      'volumes'           => [],            # We do not generate volumes, leave empty
      'components'        => [],            # Fill from the roles, see below
      'features'          => {},            # Fill from the roles, see below
      'parameters'        => [],            # Fill from the roles, see below
      'preflight'         => [],            # Fill from the roles, see below
      'postflight'        => []             # Fill from the roles, see below
    }
  end

  def process_roles(role_manifest, definition, fs)
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
      add_role(role_manifest, fs, dst, role, retries)

      # Collect per-role parameters
      if role['configuration'] && role['configuration']['variables']
        collect_parameters(gparam, role['configuration']['variables'])
      end
    end
    if role_manifest['auth']
      definition['features']['auth'] = [generate_auth_definition(role_manifest)]
    end
  end

  def collect_global_parameters(roles, definition)
    p = definition['parameters']
    if roles['configuration'] && roles['configuration']['variables']
      collect_parameters(p, roles['configuration']['variables'])
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

  def collect_properties_for_var_name_from_template_list(templates)
    templates.each do |k, v|
      parts = k.split(".", 2)
      next if parts[0] != "properties"
      next if !v.respond_to?(:scan)
      m = @ptn_match_single_var.match(v)
      if m
        var_name = m[2]
        @properties_for_var_name[var_name] = [] if !@properties_for_var_name.key?(var_name)
        @properties_for_var_name[var_name] << [parts[1], VAR_USE_SIMPLE]
        next
      end
      m = @ptn_match_var_as_field.match(v)
      if m
        field_name = m[2]
        var_name = m[4]
        @properties_for_var_name[var_name] = [] if !@properties_for_var_name.key?(var_name)
        @properties_for_var_name[var_name] << [parts[1], VAR_USE_AS_FIELD, field_name]
        next
      end
      # Treat the rest as just part of the value
      v.scan(/\(\((\w+)\)\)/) do |match|
        var_name = match[0]
        @properties_for_var_name[var_name] = [] if !@properties_for_var_name.key?(var_name)
        @properties_for_var_name[var_name] << [parts[1], VAR_USE_COMPOUND]
      end
    end
  end

  def get_best_description(var_name)
    longest_description = ""
    longest_default = ""
    # Favor properties.foo = '"blah ... ((VAR))..."' over '[{"name": "((VAR))",...]'
    saw_string_var = false
    current_use_type = VAR_USE_NONE
    @properties_for_var_name.fetch(var_name, []).each do |property, use_type, field_name|
      if use_type > current_use_type
        # We want to find the tightest use of the variable, so reject looser ones.
        # e.g. '"((FOO))"' is tighter than '"http://((HOST)).((DOMAIN))"
        next
      end
      block = @property_spec_descriptions.fetch(property, @property_null_block)
      ["default", "description"].each do |k|
        # nils and numeric values make it hard to do string-comparison, so get rid of them.
        # nil.to_s ==> ""
        block[k] = block[k].to_s
      end
      description = block["description"]
      if description.size == 0
        # No point bothering with this
        next
      end
      default = block["default"]
      accept_this_string = false
      if use_type < current_use_type
        accept_this_string = true
      else
        if use_type != current_use_type
          $stderr.puts("rm-transformer/hcp.rb: Internal error: got unexpected use-type of #{use_type}")
          exit 2
        end
        # Favor cases with both a default and a description
        if longest_description.size == 0
          accept_this_string = true
        elsif longest_description.size > 0 && longest_default.size > 0
          if description.size > longest_description.size && default.size > 0
            accept_this_string = true
          end
        elsif longest_description.size > 0 && longest_default.size == 0
          if description.size >= longest_description.size || default.size > 0
            accept_this_string = true
          end
        end
      end
      if accept_this_string
        longest_description = case use_type
                      when VAR_USE_SIMPLE ; description
                      when VAR_USE_AS_FIELD ; "the #{field_name} field of: #{description}"
                      when VAR_USE_COMPOUND ; "part of: #{description}"
                      else description
                      end
        if default.size > 0
          longest_default = default
        end
        current_use_type = use_type
      end
    end # @properties_for_var_name[var_name].each
    [longest_description, longest_default]
  end

  def get_properties_for_var_name(role_manifest)
    # {var-name => [list of property names containing the var-name]}
    role_manifest['roles'].map{|role| role.fetch('configuration',{}).fetch('templates', {})}.
          reject{|templates| templates.size == 0 }.
          each do |templates|
      collect_properties_for_var_name_from_template_list(templates)
    end
    collect_properties_for_var_name_from_template_list(role_manifest.fetch('configuration',{}).fetch('templates', {}))
  end

  # Visit all the spec files in the bosh-releases and pull out their property sections
  def collect_property_spec_descriptions
    require 'find'
    Find.find(File.join(Dir.getwd, "src")) do |path|
      parent_path, f = File.split(path)
      if f[0] == "." || f == "packages"
        Find.prune
      elsif f == "spec" && File.file?(path) && File.basename(File.dirname(parent_path)) == "jobs"
        # In Boshland we're interested in .../jobs/JOBNAME/spec
        begin
          # Ignore duplicate property names.  They usually map to the same description and
          # default strings anyway.
          @property_spec_descriptions.merge!(YAML.load_file(path).fetch('properties', {}))
        rescue Exception => ex
          $stderr.puts("rm-transformer/hcp.rb: ToHCP: Failed to load YAML file#{path}: #{ex}")
        end
      end
    end
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

  def add_role(role_manifest, fs, comps, role, retrycount)
    runtime = role['run']

    scaling = runtime['scaling']
    indexed = scaling['indexed']
    min     = scaling['min']
    max     = scaling['max']
    # temporary hack until HCF-913, HCF-914, HCF-915, HCF-916, HCF-917, HCF-884
    duplicate = scaling.fetch('duplicate', true)

    if indexed > 1 && duplicate
      # Non-trivial scaling. Replicate the role as specified,
      # with min and max computed per the HA specification.
      # The component clone is created by a recursive call
      # which cannot get here because of the 'index' getting set.
      indexed.times do |x|
        if @component_parameters
          # We have per-component information about parameters.
          # We have to make a copy for the indexed sibling.
          base = role['name']
          copy = base + "-#{x}"
          @component_parameters[copy] = @component_parameters[base]
        end

        mini = scale_min(x,indexed,min,max)
        maxi = scale_max(x,indexed,min,max)
        add_component(role_manifest, fs, comps, role, retrycount, x, mini, maxi)
      end
    else
      # Trivial scaling, no index, use min/max as is.
      add_component(role_manifest, fs, comps, role, retrycount, nil, min, max)
    end
  end

  def add_component(role_manifest, fs, comps, role, retrycount, index, min, max)
    bname = role['name']
    iname = "#{@dtr_org}/#{@hcf_prefix}-#{bname}:#{@hcf_tag}"

    rname = bname
    rname += "-#{index}" if index && index > 0

    labels = [ bname ]
    labels << rname if rname != bname

    runtime = role['run']

    the_comp = {
      'name'          => rname,
      'version'       => '0.0.0', # See also toplevel version
      'vendor'        => 'HPE',	  # See also toplevel vendor
      'image'         => iname,
      'repository'    => @dtr,
      'min_RAM_mb'    => runtime['memory'],
      'min_disk_gb'   => 1, 	# Out of thin air
      'min_VCPU'      => runtime['virtual-cpus'],
      'platform'      => 'linux-x86_64',
      'capabilities'  => runtime['capabilities'],
      'depends_on'    => [],	  # No dependency info in the RM
      'affinity'      => [],	  # No affinity info in the RM
      'labels'        => labels,  # TODO: Maybe also label with the jobs ?
      'min_instances' => min,     # See above for the calculation for the
      'max_instances' => max,     # component and its clones.
      'service_ports' => [],	  # Fill from role runtime config, see below
      'volume_mounts' => [],	  # Ditto
      'parameters'    => [],	  # Fill from role configuration, see below
      'workload_type' => 'container'
    }

    the_comp['retry_count'] = retrycount if retrycount > 0

    index = 0 if index.nil?

    unless role['type'] == 'docker'
      the_comp['entrypoint'] = build_entrypoint(index: index,
                                                runtime: runtime,
                                                role_manifest: role_manifest)
    end

    # Record persistent and shared volumes, ports
    pv = runtime['persistent-volumes']
    sv = runtime['shared-volumes']

    add_volumes(fs, the_comp, pv, index, false) if pv
    add_volumes(fs, the_comp, sv, nil, true) if sv

    add_ports(the_comp, runtime['exposed-ports']) if runtime['exposed-ports']

    # Reference global parameters
    if role_manifest['configuration'] && role_manifest['configuration']['variables']
      add_parameter_names(the_comp,
                          component_parameters(the_comp,
                                               role_manifest['configuration']['variables']))
    end

    # Reference per-role parameters
    if role['configuration'] && role['configuration']['variables']
      add_parameters(the_comp, role['configuration']['variables'])
    end

    # TODO: Should check that the intersection of between global and
    # role parameters is empty.

    comps.push(the_comp)
  end

  def build_entrypoint(options)
    bootstrap = options[:index] == 0
    entrypoint = ["/usr/bin/env", "HCF_BOOTSTRAP=#{bootstrap}"]

    # temporary hack until HCF-913, HCF-914, HCF-915, HCF-916, HCF-917, HCF-884
    duplicate = options[:runtime]['scaling'].fetch('duplicate', true)
    if duplicate
      entrypoint << "HCF_ROLE_INDEX=#{options[:index]}"
    end

    exposed_ports = options[:runtime]['exposed-ports']
    unless exposed_ports.any? {|port| port['public']}
      entrypoint << 'HCP_HOSTNAME_SUFFIX=-int'
    end

    auth_info = options[:role_manifest]['auth'] || {}
    if auth_info['clients']
      entrypoint << "UAA_CLIENTS=#{auth_info['clients'].to_json}"
    end
    if auth_info['authorities']
      entrypoint << "UAA_USER_AUTHORITIES=#{auth_info['authorities'].to_json}"
    end

    entrypoint << '/opt/hcf/run.sh'

    entrypoint
  end

  def add_volumes(fs, component, volumes, index, shared_fs)
    vols = component['volume_mounts']
    serial = 0
    volumes.each do |v|
      serial, the_vol = convert_volume(fs, v, serial, index, shared_fs)
      vols.push(the_vol)
    end
  end

  def convert_volume(fs, v, serial, index, shared_fs)
    vname = v['tag']
    if !shared_fs
      # Private volume, export now
      vsize = v['size'] # [GB], same as used by HCP, no conversion required
      serial += 1
      vname += "-#{index}" if index && index > 0

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

  def collect_parameters(para, variables)
    variables.each do |var|
      para.push(convert_parameter(var))
    end
  end

  def process_templates(rolemanifest, role)
    return unless rolemanifest['configuration'] && rolemanifest['configuration']['templates']

    templates = {}
    rolemanifest['configuration']['templates'].each do |property, template|
      templates[property] = Common.parameters_in_template(template)
    end

    if role['configuration'] && role['configuration']['templates']
      role['configuration']['templates'].each do |property, template|
        templates[property] = Common.parameters_in_template(template)
      end
    end

    templates
  end

  def determine_component_parameters(role_manifest)
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

      parameters = []
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

            parameters.push(*templates[pname])
          end
        end
      end
      @component_parameters[role['name']] = parameters.uniq.sort
    end
  end

  def component_parameters(component, variables)
    return @component_parameters[component['name']] if @component_parameters
    # If we have no per-component information we fall back to use all
    # declared parameters.
    variables.collect do |var|
      var['name']
    end
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

  def convert_parameter(var)
    vname    = var['name']
    original_vname = vname.clone
    vrequired = var.has_key?("required") ? var['required'] : true
    vsecret  = var.has_key?("secret") ? var['secret'] : false
    vexample = (var['example'] || var['default']).to_s
    vdescription = var.fetch("description", "")

    # secrets currently need to be lowercase and can only use dashes, not underscores
    # This should be handled by HCP instead: https://jira.hpcloud.net/browse/CAPS-184
    vname.downcase!.gsub!('_', '-') if vsecret

    if vdescription.size == 0
      longest_description, longest_default = get_best_description(original_vname)
      if vexample.size == 0 && longest_default.size > 0
        vexample = longest_default
      end
      vdescription = longest_description.size > 0 ? longest_description : "[no description available]"
    end
    if vexample.size == 0
      vexample = "[no example given]"
    end

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
