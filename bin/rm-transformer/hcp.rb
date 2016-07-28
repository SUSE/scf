## HCP output provider
# # ## ### ##### ########

require_relative 'common'

# Provider for HCP specifications derived from a role-manifest.
class ToHCP < Common
  def initialize(options)
    super(options)
    # In HCP the version number becomes a kubernetes label, which puts
    # some restrictions on the set of allowed characters and its
    # length.
    @hcf_version.gsub!(/[^a-zA-Z0-9.-]/, '-')
    @hcf_version = @hcf_version.slice(0,63)
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
    process_roles(roles, definition, fs)
    fixup_no_proxy(definition)

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
    # DEF.components[].external_name			/string	(*6)
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
    # (*6) Human readable name of the component
    # (*7) Container image name for component
    # (*8) See the 1st 3 attributes of components
    # (*9) Subset of comp below (- external_name + retry_count /int32)
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
    definition['parameters'] = p.sort_by { |param| param['name'] }
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
    runtime = role['run']

    scaling = runtime['scaling']
    indexed = scaling['indexed']
    min     = scaling['min']
    max     = scaling['max']

    if indexed > 1
      # Non-trivial scaling. Replicate the role as specified,
      # with min and max computed per the HA specification.
      # The component clone is created by a recursive call
      # which cannot get here because of the 'index' getting set.
      indexed.times do |x|
        mini = scale_min(x,indexed,min,max)
        maxi = scale_max(x,indexed,min,max)
        add_component(roles, fs, comps, role, retrycount, x, mini, maxi)
      end
    else
      # Trivial scaling, no index, use min/max as is.
      add_component(roles, fs, comps, role, retrycount, nil, min, max)
    end
  end

  def add_component(roles, fs, comps, role, retrycount, index, min, max)
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
      'external_name' => rname,
      'workload_type' => 'container'
    }

    the_comp['retry_count'] = retrycount if retrycount > 0

    index = 0 if index.nil?
    bootstrap = index == 0

    if role["type"] != 'docker'
      if runtime['exposed-ports'].any? {|port| port['public']}
        the_comp['entrypoint'] = ["/usr/bin/env",
                              "HCF_BOOTSTRAP=#{bootstrap}",
                              "HCF_ROLE_INDEX=#{index}",
                              "/opt/hcf/run.sh"]
      else
        the_comp['entrypoint'] = ["/usr/bin/env",
                              "HCF_BOOTSTRAP=#{bootstrap}",
                              "HCF_ROLE_INDEX=#{index}",
                              'HCP_HOSTNAME_SUFFIX=-int',
                              "/opt/hcf/run.sh"]
      end
    end

    # Record persistent and shared volumes, ports
    pv = runtime['persistent-volumes']
    sv = runtime['shared-volumes']

    add_volumes(fs, the_comp, pv, index, false) if pv
    add_volumes(fs, the_comp, sv, nil, true) if sv

    add_ports(the_comp, runtime['exposed-ports']) if runtime['exposed-ports']

    # Reference global parameters
    if roles['configuration'] && roles['configuration']['variables']
      add_parameters(the_comp, roles['configuration']['variables'])
    end

    # Reference per-role parameters
    if role['configuration'] && role['configuration']['variables']
      add_parameters(the_comp, role['configuration']['variables'])
    end

    # TODO: Should check that the intersection of between global and
    # role parameters is empty.

    comps.push(the_comp)
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

  MAX_PORT_RANGE = 10
  def add_ports(component, ports)
    cports = component['service_ports']
    ports.each do |port|
      if port['source'].to_s.include? '-'
        # HCP does not yet support port ranges; do what we can. CAPS-435
        if port['source'] != port['target']
          raise "Port range forwarding #{port['name']}: must have the same source / target ranges"
        end
        first, last = port['source'].split('-').map(&:to_i)
        if last - first > MAX_PORT_RANGE
          last = first + MAX_PORT_RANGE
          STDERR.puts "Warning: too many ports to forward in #{port['name']}, limiting to #{MAX_PORT_RANGE}"
        end
        (first..last).each do |port_number|
          cports.push(convert_port(port.merge(
            'source' => port_number,
            'target' => port_number,
            'name'   => "#{port['name']}-#{port_number}"
          )))
        end
      else
        cports.push(convert_port(port))
      end
    end
  end

  def convert_port(port)
    name = port['name']
    if name.length > 15
      # Service ports must have a length no more than 15 characters
      # (to be a valid host name)
      name = "#{name[0...8]}#{name.hash.to_s(16)[-8...-1]}"
    end
    {
      'name'        => name,
      'protocol'    => port['protocol'],
      'source_port' => port['source'],
      'target_port' => port['target'],
      'public'      => port['public']
    }
  end

  def collect_parameters(para, variables)
    variables.each do |var|
      para.push(convert_parameter(var))
    end
  end

  def add_parameters(component, variables)
    variables = variables.dup
    para = component['parameters']
    # Always include a no_proxy reference for HCP use
    %w(no_proxy NO_PROXY).each do |name|
      variables << { 'name' => name } if variables.none? { |p| p['name'] == name }
    end
    variables.each do |var|
      para.push(convert_parameter_ref(var))
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
      'default'     => (var['default'].nil? || vsecret) ? nil : var['default'].to_s
    }

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

  # Fix up the no_proxy environment variables to always skip local roles
  def fixup_no_proxy(definition)
    role_names = definition['components'].map { |comp| comp['name'] }
    host_names = role_names.map { |name| "#{name}-int" }
    %w(no_proxy NO_PROXY).each do |name|
      param = definition['parameters'].select { |p| p['name'] == name }.first
      if param.nil?
        param = convert_parameter('name' => name)
        definition['parameters'] << param
      end
      values = (param['default'] || '').split(',') + host_names
      param['default'] = values.uniq.sort.join(',')
    end
  end

  # # ## ### ##### ########
end

# # ## ### ##### ########
