#!/usr/bin/env ruby

require 'yaml'
require 'json'

def get_roles(path)
  YAML.load_file(path)

  # Loaded structure
  ##
  # the_roles.roles[].name				/string
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
    vdefault = var['default']

    the_para = {
      'name'        => vname,
      'description' => '',
      'default'     => vdefault,
      'example'     => '',
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
      'mount_point' => vmount
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
    next unless runtime['shared-volumes']
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

def roles_to_ucp(roles)
  the_ucp = {
    'name'       => 'HDP CF', # TODO: Specify via option?
    'version'    => '0.0.0',  # s.a.
    'vendor'     => 'HPE',    # s.a.
    'volumes'    => [],	      # We do not generate volumes, leave empty
    'components' => []	      # Fill from the roles, see below
  }

  comp = the_ucp['components']
  fs   = the_ucp['volumes']
 
  save_shared_filesystems(fs, collect_shared_filesystems(roles['roles']))

  # Phase II. Generate UCP data per-role.
  roles['roles'].each do |role|
    rname = role['name']
    ename = rname # TODO: construct proper external name
    iname = rname # TODO: construct proper image name

    runtime = role['run']

    the_comp = {
      'name'          => rname,
      'version'       => '0.0.0', # See also toplevel version
      'vendor'        => 'HPE',	  # See also toplevel vendor
      'external_name' => ename,
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
      'parameters'    => []	# Fill from role configuration, see below
    }

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

    comp.push(the_comp)
  end

  the_ucp
  # Generated structure
  ##
  # the_ucp.name
  # the_ucp.version
  # the_ucp.vendor
  # the_ucp.volumes[].name
  # the_ucp.volumes[].size_gb
  # the_ucp.volumes[].filesystem
  # the_ucp.volumes[].shared
  # the_ucp.components[].name
  # the_ucp.components[].version
  # the_ucp.components[].vendor
  # the_ucp.components[].external_name
  # the_ucp.components[].image
  # the_ucp.components[].min_RAM_mb		/float
  # the_ucp.components[].min_disk_gb		/float
  # the_ucp.components[].min_VCPU		/int
  # the_ucp.components[].platform
  # the_ucp.components[].capabilities[]
  # the_ucp.components[].depends_on[].name	/string \See 1st 3 comp attributes
  # the_ucp.components[].depends_on[].version	/string \
  # the_ucp.components[].depends_on[].vendor	/string \
  # the_ucp.components[].affinity[]		/?
  # the_ucp.components[].labels[]
  # the_ucp.components[].min_instances		/int
  # the_ucp.components[].max_instances		/int
  # the_ucp.components[].service_ports[].name
  # the_ucp.components[].service_ports[].protocol
  # the_ucp.components[].service_ports[].source_port
  # the_ucp.components[].service_ports[].target_port
  # the_ucp.components[].service_ports[].public		/bool
  # the_ucp.components[].volume_mounts[].volume_name
  # the_ucp.components[].volume_mounts[].mountpoint
  # the_ucp.components[].parameters[].name
  # the_ucp.components[].parameters[].description
  # the_ucp.components[].parameters[].default
  # the_ucp.components[].parameters[].example
  # the_ucp.components[].parameters[].required		/bool
  # the_ucp.components[].parameters[].secret		/bool
end

def save_ucp(path, ucp)
  File.open(path, 'w') do |handle|
    # handle.puts (JSON.generate(ucp))

    # While in dev I want something at least semi-readable
    handle.puts(JSON.pretty_generate(ucp))
  end
end

def main
  # Syntax: <roles-manifest.yml> <ucp-manifest.json>
  # Process arguments
  # - origin      = roles manifest
  # - destination = ucp manifest

  origin      = ARGV[0]
  destination = ARGV[1]

  # Read roles manifest
  # Generate ucp manifest
  # Write ucp manifest

  save_ucp(destination, roles_to_ucp(get_roles(origin)))
end

main
