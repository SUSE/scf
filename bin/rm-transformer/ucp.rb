## UCP output provider
# # ## ### ##### ########

# Provider for UCP specifications derived from a role-manifest.
class ToUCP
  def initialize(options, remainder)
    raise 'UCP conversion does not accept add-on files' if remainder &&
                                                           !remainder.empty?
    @options = options
    initialize_dtr_information
  end

  def initialize_dtr_information
    # Get options, set defaults for missing parts
    @dtr         = @options[:dtr] || 'docker.helion.lol'
    @dtr_org     = @options[:dtr_org] || 'helioncf'
    @hcf_version = @options[:hcf_version] || 'develop'
    @hcf_prefix  = @options[:hcf_prefix] || 'hcf'

    @dtr = "#{@dtr}/" unless @dtr.empty?
  end

  # Public API
  def transform(roles)
    JSON.pretty_generate(to_ucp(roles))
  end

  # Internal definitions

  def to_ucp(roles)
    the_ucp = empty_ucp

    fs = the_ucp['volumes']
    save_shared_filesystems(fs, collect_shared_filesystems(roles['roles']))
    process_roles(roles, the_ucp, fs)

    the_ucp
    # Generated structure
    ##
    # the_ucp.name					/string
    # the_ucp.version					/string
    # the_ucp.vendor					/string
    # the_ucp.preflight[].				(*9)
    # the_ucp.postflight[].				(*9)
    # the_ucp.volumes[].name				/string
    # the_ucp.volumes[].size_gb				/int32
    # the_ucp.volumes[].filesystem			/string (*2)
    # the_ucp.volumes[].shared				/bool
    # the_ucp.components[].name				/string
    # the_ucp.components[].version			/string
    # the_ucp.components[].vendor			/string
    # the_ucp.components[].external_name		/string	(*6)
    # the_ucp.components[].image			/string	(*7)
    # the_ucp.components[].min_RAM_mb			/int32
    # the_ucp.components[].min_disk_gb			/int32
    # the_ucp.components[].min_VCPU			/int32
    # the_ucp.components[].platform			/string	(*3)
    # the_ucp.components[].capabilities[]		/string (*1)
    # the_ucp.components[].workload_type		/string (*4)
    # the_ucp.components[].entrypoint[]			/string (*5)
    # the_ucp.components[].depends_on[].name		/string \(*8)
    # the_ucp.components[].depends_on[].version		/string \
    # the_ucp.components[].depends_on[].vendor		/string \
    # the_ucp.components[].affinity[]			/string
    # the_ucp.components[].labels[]			/string
    # the_ucp.components[].min_instances		/int
    # the_ucp.components[].max_instances		/int
    # the_ucp.components[].service_ports[].name		/string
    # the_ucp.components[].service_ports[].protocol	/string	('TCP', 'UDP')
    # the_ucp.components[].service_ports[].source_port	/int32
    # the_ucp.components[].service_ports[].target_port	/int32
    # the_ucp.components[].service_ports[].public	/bool
    # the_ucp.components[].volume_mounts[].volume_name	/string
    # the_ucp.components[].volume_mounts[].mountpoint	/string
    # the_ucp.components[].parameters[].name		/string
    # the_ucp.components[].parameters[].description	/string, !empty
    # the_ucp.components[].parameters[].default		/string
    # the_ucp.components[].parameters[].example		/string, !empty
    # the_ucp.components[].parameters[].required	/bool
    # the_ucp.components[].parameters[].secret		/bool
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

  def process_roles(roles, the_ucp, fs)
    comp = the_ucp['components']
    post = the_ucp['postflight']

    roles['roles'].each do |role|
      type = role['type'] || 'bosh'

      next if type == 'docker' ||
              (type == 'bosh-task' &&
               role['dev-only'] &&
               !@options[:dev])

      rc = choose(type, 5, 0)
      dst = choose(type, post, comp)

      add_component(roles, fs, dst, role, rc)
    end
  end

  def choose(type, task, job)
    if type == 'bosh-task'
      task
    else
      job
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
    {
      'name'        => vname,
      'description' => 'placeholder',
      'default'     => vdefault,
      'example'     => vdefault || 'unknown',
      'required'    => true,
      'secret'      => false
    }
  end

  # # ## ### ##### ########
end

# # ## ### ##### ########
