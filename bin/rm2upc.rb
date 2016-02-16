#!/usr/bin/env ruby

# requirements ?

def get_roles(path)
  # TODO yaml reader
  return nil
end

def roles_to_upc(roles)
  # TODO map structures
  return nil
end

def save_upc(path,upc)
  # TODO json writer
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
