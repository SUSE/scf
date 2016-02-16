#!/usr/bin/env ruby

require 'yaml'
require 'json'

def get_roles(path)
  return YAML.load_file(path)

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
  # the_roles.configuration.variables[].name		/string
  # the_roles.configuration.variables[].default		/string
  # the_roles.configuration.templates.<any>		/string
end

def roles_to_upc(roles)
  the_upc = {
    "name"       => "HDP CF",	# Specify via option?
    "version"    => "0.0.0",	# s.a.
    "vendor"     => "HPE",	# s.a.
    "volumes"    => [],		# We do not generate volumes, leave empty
    "components" => [],		# Fill from the roles, see below
  }

  comp = the_upc["components"]
  roles["roles"].each do |role|
    rname = role["name"]
    ename = rname # TODO construct proper external name
    iname = rname # TODO construct proper image name

    the_comp = {
      "name"          => rname,
      "version"       => "0.0.0",	# See also toplevel version
      "vendor"        => "HPE",		# See also toplevel vendor
      "external_name" => ename,
      "image"         => iname,
      "min_RAM_mb"    => 128,		# Pulled out of thin air
      "min_disk_gb"   => 1,		# Ditto
      "min_VCPU"      => 1,
      "platform"      => "linux-x86_64",
      "capabilities"  => ["ALL"],	# This could be role-specific (privileged vs not)
      "depends_on"    => [],		# No dependency info in the RM
      "affinity"      => [],		# No affinity info in the RM
      "labels"        => [rname],	# Maybe also label with the jobs inside ?
      "min_instances" => 1,
      "max_instances" => 1,
      "service_ports" => [],		# This might require role-specific alteration
      "volume_mounts" => [],
      "parameters"    => [],		# Fill from role configuration, see below
    }

    para = the_comp["parameters"]

    role["configuration"] && \
    role["configuration"]["templates"] && \
    role["configuration"]["templates"].each do |k, v|
      the_para = {
        "name"        => k,
        "description" => "",
        "default"     => "",	# TODO construct proper default from template ?
        			# Where do the values to subst in come from ?
        "example"     => v,	# Using template string in RM for the example for now.
        "required"    => true,	# TODO flip to false when we have a default.
        "secret"      => false,
      }

      para.push the_para
    end

    comp.push the_comp
  end

  return the_upc
  # Generated structure
  ##
  # the_upc.name
  # the_upc.version
  # the_upc.vendor
  # the_upc.volumes[].name
  # the_upc.volumes[].size_gb
  # the_upc.volumes[].filesystem
  # the_upc.volumes[].shared
  # the_upc.components[].name
  # the_upc.components[].version
  # the_upc.components[].vendor
  # the_upc.components[].external_name
  # the_upc.components[].image
  # the_upc.components[].min_RAM_mb		/float
  # the_upc.components[].min_disk_gb		/float
  # the_upc.components[].min_VCPU		/int
  # the_upc.components[].platform
  # the_upc.components[].capabilities[]
  # the_upc.components[].depends_on[].name	/string \See 1st 3 comp attributes
  # the_upc.components[].depends_on[].version	/string \
  # the_upc.components[].depends_on[].vendor	/string \
  # the_upc.components[].affinity[]		/?
  # the_upc.components[].labels[]
  # the_upc.components[].min_instances		/int
  # the_upc.components[].max_instances		/int
  # the_upc.components[].service_ports[].name
  # the_upc.components[].service_ports[].protocol
  # the_upc.components[].service_ports[].source_port
  # the_upc.components[].service_ports[].target_port
  # the_upc.components[].service_ports[].public		/bool
  # the_upc.components[].volume_mounts[].volume_name
  # the_upc.components[].volume_mounts[].mountpoint
  # the_upc.components[].parameters[].name
  # the_upc.components[].parameters[].description
  # the_upc.components[].parameters[].default
  # the_upc.components[].parameters[].example
  # the_upc.components[].parameters[].required		/bool
  # the_upc.components[].parameters[].secret		/bool
end

def save_upc(path,upc)
  File.open(path,"w") do |handle|
    #handle.puts (JSON.generate upc)

    # While in dev I want something at least semi-readable
    handle.puts (JSON.pretty_generate upc)
  end
end

def main
  # Syntax: <roles-manifest.yml> <upc-manifest.json>
  # Process arguments
  # - origin      = roles manifest
  # - destination = upc manifest

  origin      = ARGV[0]
  destination = ARGV[1]

  # Read roles manifest
  # Generate upc manifest
  # Write upc manifest

  roles = get_roles origin
  upc   = roles_to_upc roles
  save_upc destination, upc
end

main
