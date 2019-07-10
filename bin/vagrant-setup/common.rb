# -*- coding: utf-8 -*-
## Common functionality for all providers.
# # ## ### ##### ########
require 'mustache'

# Colorization support.
class String
  def red
    "\033[0;31m#{self}\033[0m"
  end

  def green
    "\033[0;32m#{self}\033[0m"
  end

  def yellow
    "\033[0;33m#{self}\033[0m"
  end

  def blue
    "\033[0;34m#{self}\033[0m"
  end

  def magenta
    "\033[0;35m#{self}\033[0m"
  end

  def cyan
    "\033[0;36m#{self}\033[0m"
  end
end

# Common functionality for all providers.
class Common

  def self.load_role_manifest(path)
    if path == '-'
      # Read from stdin.
      role_manifest = YAML.load($stdin)
    else
      role_manifest = YAML.load_file(path)
    end

    role_manifest
  end

  def self.parameters_in_template(template)
    # Note: The prefix "{{=(( ))=}}" is required because role manifest
    # uses ((, )) as delimiters by default, which is non-default for
    # mustache. The prefix activates our delimiters.

    template = template.to_s
    tokens = Mustache::Template.new("{{=(( ))=}}" + template).tokens

    vars = []
    vars_in_tokens(vars, tokens)
    vars.uniq
  end

  def self.vars_in_tokens(vars, tokens)
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
end
