#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'json'

def get_roles(path)
  if path == '-'
    # Read from stdin.
    YAML.load($stdin)
  else
    YAML.load_file(path)
  end
  # Loaded structure
  ##
  # the_roles.roles[].name				/string
  # the_roles.roles[].dev-only				/bool
  # the_roles.roles[].type				/string (allowed "bosh-task")
  # the_roles.roles[].scripts[]				/string
  # the_roles.roles[].jobs[].name			/string
  # the_roles.roles[].jobs[].release_name		/string
  # the_roles.roles[].processes[].name			/string
  # the_roles.roles[].configuration.variables[].name	/string
  # the_roles.roles[].configuration.variables[].default	/string
  # the_roles.roles[].configuration.templates.<any>	/string
  # the_roles.roles[].run.capabilities[]		/string
  # the_roles.roles[].run.persistent-volumes[].path	/string, mountpoint
  # the_roles.roles[].run.persistent-volumes[].size	/float [GB]
  # the_roles.roles[].run.shared-volumes[].path		/string, mountpoint
  # the_roles.roles[].run.shared-volumes[].size		/float [GB]
  # the_roles.roles[].run.shared-volumes[].tag		/string
  # the_roles.roles[].run.memory			/float [MB]
  # the_roles.roles[].run.virtual-cpus			/int
  # the_roles.roles[].run.exposed-ports[].name		/string
  # the_roles.roles[].run.exposed-ports[].protocol	/string
  # the_roles.roles[].run.exposed-ports[].source	/int
  # the_roles.roles[].run.exposed-ports[].target	/int
  # the_roles.roles[].run.exposed-ports[].public	/bool
  # the_roles.roles[].run.hosts.<any>			/string (name -> ip-addr)
  # the_roles.configuration.variables[].name		/string
  # the_roles.configuration.variables[].default		/string
  # the_roles.configuration.templates.<any>		/string (key -> value)
end

def add_parameters(component, variables)
  para = component['parameters']

  variables.each do |var|
    vname    = var['name']
    vdefault = var['default'].to_s

    the_para = {
      'name'        => vname,
      'description' => 'placeholder',
      'default'     => vdefault,
      'example'     => vdefault || 'unknown',
      'required'    => true,
      'secret'      => false
    }

    para.push(the_para)
  end
end

def add_volumes(fs, component, volumes)
  vols = component['volume_mounts']
  serial = 0

  volumes.each do |v|
    vmount = v['path']
    if v['tag']
      # Shared volume, already collected
      vname = v['tag']
    else
      # Private volume, export now
      vname = 'V$' + component['name'] + '$' + serial.to_s
      vsize = v['size'] # [GB], same as used by UCP, no conversion required
      serial += 1

      add_filesystem(fs, vname, vsize, false)
    end

    the_vol = {
      'volume_name' => vname,
      'mountpoint' => vmount
    }

    vols.push(the_vol)
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

def add_ports(component, ports)
  cports = component['service_ports']
  ports.each do |port|
    cports.push(convert_port(port))
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

def abort_on_mismatch(shared, vname, vsize)
  if shared[vname] && vsize != shared[vname]
    # Raise error about definition mismatch
    raise 'Size mismatch for shared volume "' + vname + '": ' +
      vsize + ', previously ' + shared[vname]
  end
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

def save_shared_filesystems(fs, shared)
  shared.each do |vname, vsize|
    add_filesystem(fs, vname, vsize, true)
  end
end

def add_component(roles, fs, comps, role, retrycount = 0)
  rname = role['name']
  iname = rname # TODO: construct proper image name

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
    'external_name' => "HCF Role '#{rname}'"
  }

  if retrycount > 0
    the_comp['retry_count'] = retrycount
  end

  # Record persistent and shared volumes, ports
  add_volumes(fs, the_comp, runtime['persistent-volumes']) if runtime['persistent-volumes']
  add_volumes(fs, the_comp, runtime['shared-volumes']) if runtime['shared-volumes']

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

def roles_to_ucp(roles)
  the_ucp = {
    'name'       => 'HDP CF', # TODO: Specify via option?
    'version'    => '0.0.0',  # s.a.
    'vendor'     => 'HPE',    # s.a.
    'volumes'    => [],	      # We do not generate volumes, leave empty
    'components' => [],	      # Fill from the roles, see below
    'preflight'  => [],	      # Fill from the roles, see below
    'postflight' => []	      # Fill from the roles, see below
  }

  comp = the_ucp['components']
  post = the_ucp['postflight']
  fs   = the_ucp['volumes']

  save_shared_filesystems(fs, collect_shared_filesystems(roles['roles']))

  # Phase II. Generate UCP data per-role.
  roles['roles'].each do |role|
    type = role['type']
    if type && type == 'bosh-task'
      # Ignore dev parts by default.
      next if role['dev-only'] && !$options[:dev]

      add_component(roles, fs, post, role, 5)
      # 5 == default retry count.
      #   Option to override ?
      #   Manifest override?
    else
      add_component(roles, fs, comp, role)
    end
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

def save_ucp(path, ucp)
  if path == '-'
    $stdout.puts(JSON.pretty_generate(ucp))
  else
    File.open(path, 'w') do |handle|
      # handle.puts (JSON.generate(ucp))

      # While in dev I want something at least semi-readable
      handle.puts(JSON.pretty_generate(ucp))
    end
  end
end

def main
  # Syntax: ?--dev? <roles-manifest.yml>|- <ucp-manifest.json>|-
  # Process arguments
  # & --dev       ~ Include dev-only parts in generated UCP service definition
  # & origin      = roles manifest, or stdin (-)
  # & destination = UCP service definition, or stdout (-)

  $options = {}
  op = OptionParser.new do |opts|
    opts.banner = 'Usage: rm2ucp [--dev] role-manifest|- ucp-service|-

        Read the role-manifest from the specified file, or stdin (-),
        then generate the equivalent UCP service definition.
        The result is written to ucp-service, or stdout (-).

'

    opts.on('-d', '--dev', 'Include dev-only parts in the output') do |v|
      $options[:dev] = v
    end
  end
  op.parse!

  if ARGV.length != 2
    op.parse!(['--help'])
    exit 1
  end

  origin      = ARGV[0]
  destination = ARGV[1]

  # Read roles manifest
  # Generate ucp manifest
  # Write ucp manifest

  save_ucp(destination, roles_to_ucp(get_roles(origin)))
end

main
