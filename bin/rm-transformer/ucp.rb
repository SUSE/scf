## UCP output provider
# # ## ### ##### ########

# Provider for UCP specifications derived from a role-manifest.
class ToUCP
  def initialize(options, remainder)
    raise 'UCP conversion does not accept add-on files' if remainder && !remainder.empty?
    @options = options
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
    the_ucp = {
      'name'       => 'hcf',    # TODO: Specify via option?
      'version'    => '0.0.0',  # s.a.
      'vendor'     => 'HPE',    # s.a.
      'volumes'    => [],	# We do not generate volumes, leave empty
      'components' => [],	# Fill from the roles, see below
      'preflight'  => [],	# Fill from the roles, see below
      'postflight' => []	# Fill from the roles, see below
    }

    comp = the_ucp['components']
    post = the_ucp['postflight']
    fs   = the_ucp['volumes']

    save_shared_filesystems(fs, collect_shared_filesystems(roles['roles']))

    # Phase II. Generate UCP data per-role.
    roles['roles'].each do |role|
      type = role['type'] || 'bosh'

      next if type == 'docker'

      if type == 'bosh-task'
        # Ignore dev parts by default.
        next if role['dev-only'] && !@options[:dev]

        add_component(roles, fs, post, role, 5)
        # 5 == default retry count.
        #   Option to override ?
        #   Manifest override?
        next
      end

      add_component(roles, fs, comp, role)
    end

    the_ucp
    # Generated structure
    ##
    # the_ucp.name					/string
    # the_ucp.version					/string
    # the_ucp.vendor					/string
    # the_ucp.preflight[].	subset of comp below (- external_name + retry_count /int32)
    # the_ucp.postflight[].	Ditto
    # the_ucp.volumes[].name				/string
    # the_ucp.volumes[].size_gb				/int32
    # the_ucp.volumes[].filesystem			/string ('ext4', 'xfs', 'ntfs' (platform-dependent))
    # the_ucp.volumes[].shared				/bool
    # the_ucp.components[].name				/string
    # the_ucp.components[].version			/string
    # the_ucp.components[].vendor				/string
    # the_ucp.components[].external_name			/string	Human readable name of the component
    # the_ucp.components[].image				/string	Container image name for component
    # the_ucp.components[].min_RAM_mb			/int32
    # the_ucp.components[].min_disk_gb			/int32
    # the_ucp.components[].min_VCPU			/int32
    # the_ucp.components[].platform			/string	('linux-x86_64', 'win2012r2-x86_64')
    # the_ucp.components[].capabilities[]			/string (*1)
    # the_ucp.components[].workload_type			/string ('container', 'vm')
    # the_ucp.components[].entrypoint[]			/string (cmd and parameters, each a separate entry)
    # the_ucp.components[].depends_on[].name		/string \See 1st 3 comp attributes
    # the_ucp.components[].depends_on[].version		/string \
    # the_ucp.components[].depends_on[].vendor		/string \
    # the_ucp.components[].affinity[]			/string
    # the_ucp.components[].labels[]			/string
    # the_ucp.components[].min_instances			/int
    # the_ucp.components[].max_instances			/int
    # the_ucp.components[].service_ports[].name		/string
    # the_ucp.components[].service_ports[].protocol	/string	('TCP', 'UDP')
    # the_ucp.components[].service_ports[].source_port	/int32
    # the_ucp.components[].service_ports[].target_port	/int32
    # the_ucp.components[].service_ports[].public		/bool
    # the_ucp.components[].volume_mounts[].volume_name	/string
    # the_ucp.components[].volume_mounts[].mountpoint	/string
    # the_ucp.components[].parameters[].name		/string
    # the_ucp.components[].parameters[].description	/string, !empty
    # the_ucp.components[].parameters[].default		/string
    # the_ucp.components[].parameters[].example		/string, !empty
    # the_ucp.components[].parameters[].required		/bool
    # the_ucp.components[].parameters[].secret		/bool
    #
    # (*1) Too many to list here. See ucp-developer/service_models.md for the full list.
    #      Notables:
    #      - ALL
    #      - NET_ADMIN
    #      Note further, NET_RAW accepted, but not supported.
  end

  def collect_shared_filesystems(roles)
    shared = {}
    roles.each do |role|
      runtime = role['run']
      next unless runtime && runtime['shared-volumes']

      runtime['shared-volumes'].each do |v|
        vname = v['tag']
        vsize = v['size']
        abort_on_mismatch(shared, vname, vsize)
        shared[vname] = vsize
      end
    end
    shared
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
      'min_disk_gb'   => 1,	  		# Out of thin air
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
    add_volumes(fs, the_comp, runtime['persistent-volumes'], false) if runtime['persistent-volumes']
    add_volumes(fs, the_comp, runtime['shared-volumes'], true) if runtime['shared-volumes']

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
    vmount = v['path']
    vname = v['tag']
    if !shared_fs
      # Private volume, export now
      vsize = v['size'] # [GB], same as used by UCP, no conversion required
      serial += 1

      add_filesystem(fs, vname, vsize, false)
    end

    [serial, {
       'volume_name' => vname,
       'mountpoint'  => vmount
    }]
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
