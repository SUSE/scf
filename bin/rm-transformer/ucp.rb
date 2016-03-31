## UCP output provider
# # ## ### ##### ########

require_relative 'common'

# Provider for UCP specifications derived from a role-manifest.
class ToUCP < Common
  def initialize(options)
    super(options)
    @dtr = "#{@dtr}/" unless @dtr.empty?
  end

  # Public API
  def transform(roles)
    JSON.pretty_generate(to_ucp(roles))
  end

  # Internal definitions

  def to_ucp(roles)
    definition = empty_ucp

    fs = definition['volumes']
    save_shared_filesystems(fs, collect_shared_filesystems(roles['roles']))
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
    # DEF.components[].parameters[].description		/string, !empty
    # DEF.components[].parameters[].default		/string
    # DEF.components[].parameters[].example		/string, !empty
    # DEF.components[].parameters[].required		/bool
    # DEF.components[].parameters[].secret		/bool
    #
    # (*1) Too many to list here. See ucp-developer/service_models.md
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

  def empty_ucp
    {
      'name'       => 'hcf',    # TODO: Specify via option?
      'version'    => '0.0.0',  # s.a.
      'vendor'     => 'HPE',    # s.a.
      'volumes'    => [],	# We do not generate volumes, leave empty
      'components' => [],	# Fill from the roles, see below
      'preflight'  => [],	# Fill from the roles, see below
      'postflight' => []	# Fill from the roles, see below
    }
  end

  def process_roles(roles, definition, fs)
    section_map = {
        'pre-flight'  => 'preflight',
        'flight'      => 'components',
        'post-flight' => 'postflight'
    }
    roles['roles'].each do |role|
      # UCP doesn't have manual jobs
      next if flight_stage_of(role) == 'manual'

      retries = task?(role) ? 5 : 0
      dst = definition[section_map[flight_stage_of(role)]]
      add_component(roles, fs, dst, role, retries)
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

  def add_component(roles, fs, comps, role, retrycount = 0)
    rname = role['name']
    iname = "#{@dtr}#{@dtr_org}/#{@hcf_prefix}-#{rname}:#{@hcf_version}"

    runtime = role['run']

    the_comp = {
      'name'          => rname,
      'version'       => '0.0.0', # See also toplevel version
      'vendor'        => 'HPE',	  # See also toplevel vendor
      'image'         => iname,
      'min_RAM_mb'    => runtime['memory'],
      'min_disk_gb'   => 1, 	# Out of thin air
      'min_VCPU'      => runtime['virtual-cpus'],
      'platform'      => 'linux-x86_64',
      'capabilities'  => runtime['capabilities'],
      'depends_on'    => [],	  # No dependency info in the RM
      'affinity'      => [],	  # No affinity info in the RM
      'labels'        => [rname], # TODO: Maybe also label with the jobs ?
      'min_instances' => 1,
      'max_instances' => 1,
      'service_ports' => [],	# Fill from role runtime config, see below
      'volume_mounts' => [],	# Ditto
      'parameters'    => [],	# Fill from role configuration, see below
      'external_name' => "HCF Role '#{rname}'",
      'workload_type' => 'container'
    }

    the_comp['retry_count'] = retrycount if retrycount > 0

    # Record persistent and shared volumes, ports
    pv = runtime['persistent-volumes']
    sv = runtime['shared-volumes']

    add_volumes(fs, the_comp, pv, false) if pv
    add_volumes(fs, the_comp, sv, true) if sv

    add_ports(the_comp, runtime['exposed-ports']) if runtime['exposed-ports']

    # Global parameters
    if roles['configuration'] && roles['configuration']['variables']
      add_parameters(the_comp, roles['configuration']['variables'])
    end

    # Per role parameters
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
      vsize = v['size'] # [GB], same as used by UCP, no conversion required
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

  def add_ports(component, ports)
    cports = component['service_ports']
    ports.each do |port|
      cports.push(convert_port(port))
    end
  end

  def convert_port(port)
    {
      'name'        => port['name'],
      'protocol'    => port['protocol'],
      'source_port' => port['source'],
      'target_port' => port['target'],
      'public'      => port['public']
    }
  end

  def add_parameters(component, variables)
    para = component['parameters']
    variables.each do |var|
      para.push(convert_parameter(var))
    end
  end

  def convert_parameter(var)
    vname    = var['name']
    vdefault = var['default'].to_s
    vsecret  = var['secret'] || false
    vexample = (var['example'] || var['default']).to_s
    vexample = 'unknown' if vexample == ''
    param = {
      'name'        => vname,
      'description' => 'placeholder',
      'example'     => vexample,
      'required'    => true,
      'secret'      => vsecret,
    }
    param['default'] = vdefault unless vdefault == ''
    return param
  end

  # # ## ### ##### ########
end

# # ## ### ##### ########
