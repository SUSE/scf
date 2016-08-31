## HCP output provider
# # ## ### ##### ########

# Put file's location into the load path. Mustache does not use 'require_relative'
$:.unshift File.dirname(__FILE__)

require 'mustache'
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
  def transform(roles)
    JSON.pretty_generate(to_hcp(roles))
  end

  # Internal definitions

  def to_hcp(roles)
    definition = empty_hcp

    fs = definition['volumes']
    save_shared_filesystems(fs, collect_shared_filesystems(roles['roles']))
    collect_global_parameters(roles, definition)
    determine_component_parameters(roles)
    process_roles(roles, definition, fs)

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
      'parameters'        => [],            # Fill from the roles, see below
      'preflight'         => [],            # Fill from the roles, see below
      'postflight'        => []             # Fill from the roles, see below
    }
  end

  def process_roles(roles, definition, fs)
    section_map = {
      'pre-flight'  => 'preflight',
      'flight'      => 'components',
      'post-flight' => 'postflight'
    }
    gparam = definition['parameters']
    roles['roles'].each do |role|
      # HCP doesn't have manual jobs
      next if flight_stage_of(role) == 'manual'
      next if tags_of(role).include?('dev-only')

      # We don't run to infinity because we will flood HCP if we do
      retries = task?(role) ? 5 : 0
      dst = definition[section_map[flight_stage_of(role)]]
      add_role(roles, fs, dst, role, retries)

      # Collect per-role parameters
      if role['configuration'] && role['configuration']['variables']
        collect_parameters(gparam, role['configuration']['variables'])
      end
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

  def add_role(roles, fs, comps, role, retrycount)
    bname = role['name']
    iname = "#{@dtr_org}/#{@hcf_prefix}-#{bname}:#{@hcf_tag}"

    labels = [ bname ]

    runtime = role['run']
    scaling = runtime['scaling']
    min     = scaling['min']
    max     = scaling['max']

    the_comp = {
      'name'          => bname,
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

    if role["type"] != 'docker'
      if runtime['exposed-ports'].any? {|port| port['public']}
        the_comp['entrypoint'] = ["/usr/bin/env",
                              "/opt/hcf/run.sh"]
      else
        the_comp['entrypoint'] = ["/usr/bin/env",
                              'HCP_HOSTNAME_SUFFIX=-int',
                              "/opt/hcf/run.sh"]
      end
    end

    # Record persistent and shared volumes, ports
    pv = runtime['persistent-volumes']
    sv = runtime['shared-volumes']

    add_volumes(fs, the_comp, pv, false) if pv
    add_volumes(fs, the_comp, sv, true) if sv

    add_ports(the_comp, runtime['exposed-ports']) if runtime['exposed-ports']

    # Reference global parameters
    if roles['configuration'] && roles['configuration']['variables']
      add_parameter_names(the_comp,
                          component_parameters(the_comp,
                                               roles['configuration']['variables']))
    end

    # Reference per-role parameters
    if role['configuration'] && role['configuration']['variables']
      add_parameters(the_comp, role['configuration']['variables'])
    end

    # TODO: Should check that the intersection of between global and
    # role parameters is empty.

    comps.push(the_comp)
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

  def collect_parameters(para, variables)
    @allpara = {}
    variables.each do |var|
      @allpara[var['name']] = nil ;# value irrelevant. See 'process_templates' for use.
      para.push(convert_parameter(var))
    end
  end

  def process_templates(rolemanifest)
    return unless rolemanifest['configuration'] && rolemanifest['configuration']['templates']

    templates = {}
    rolemanifest['configuration']['templates'].each do |property, template|
      templates[property] = parameters_in_template(template)

      # Report all templates which contain references to unknown
      # variables, and the bogus variables themselves.  We ignore the
      # undeclared variables provided by HCP, these are ok.  See
      # 'collect_parameters' (above) for the place filling @allpara.

      templates[property].each do |vname|
        next if @allpara.has_key? vname
        next if /^HCP_/ =~ vname

        STDERR.puts "Template \033[0;31m#{property}\033[0m: Referencing undeclared variable \033[0;31m#{vname}\033[0m"
      end
    end

    templates
  end

  def parameters_in_template(template)
    # Note: The prefix "{{=(( ))=}}" is required because role manifest
    # uses ((, )) as delimiters by default, which is non-default for
    # mustache. The prefix activates our delimiters.

    template = template.to_s
    tokens = Mustache::Template.new("{{=(( ))=}}" + template).tokens

    vars = []
    vars_in_tokens(vars, tokens)
    vars.uniq
  end

  def vars_in_tokens(vars,tokens)
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

  def determine_component_parameters(rolemanifest)
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

    templates = process_templates(rolemanifest)
    return unless templates

    @component_parameters = {}
    rolemanifest['roles'].each do |role|
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
    vrequired = var.has_key?("required") ? var['required'] : true
    vsecret  = var.has_key?("secret") ? var['secret'] : false
    vexample = (var['example'] || var['default']).to_s
    vexample = 'unknown' if vexample == ''

    # secrets currently need to be lowercase and can only use dashes, not underscores
    # This should be handled by HCP instead: https://jira.hpcloud.net/browse/CAPS-184
    vname.downcase!.gsub!('_', '-') if vsecret

    parameter = {
      'name'        => vname,
      'description' => 'placeholder',
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

  # # ## ### ##### ########
end

# # ## ### ##### ########
