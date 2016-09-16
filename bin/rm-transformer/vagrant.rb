## VAGRANT output provider
# # ## ### ##### ########

# Put file's location into the load path. Mustache does not use 'require_relative'
$:.unshift File.dirname(__FILE__)

require 'common'

# Provider for VAGRANT specifications derived from a role-manifest.
class ToVAGRANT < Common
  def initialize(options)
    super(options)

    # Quick access to the loaded properties: (release -> job -> property -> default-value)
    # For the filtering we need:             (release -> job -> list(property))

    @property = Hash.new do |props, release|
      props[release] = Hash.new do |release_hash, job|
        release_hash[job] = []
      end
    end

    @options[:propmap].each do |release, jobs|
      jobs.each do |job, properties|
        properties.each_key do |property|
          @property[release][job] << property
        end
      end
    end
  end

  # Public API
  def transform(role_manifest)
    JSON.pretty_generate(to_vagrant(role_manifest))
  end

  # Internal definitions

  def to_vagrant(role_manifest)
    definition = empty_vagrant
    determine_component_parameters(definition,role_manifest)
    definition
  end

  def empty_vagrant
    {
    }
  end

  def determine_component_parameters(definition,rolemanifest)
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

    rolemanifest['roles'].each do |role|
      templates = process_templates(rolemanifest, role)
      return unless templates

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

            # If we have a special property (that contains a hash) we need to
            # include all templates that are part of it in our search
            if Common.special_property(pname)
              templates.each do |key, templ|
                next unless key =~ Regexp.new("^#{pname}")
                parameters.push(*templates[key])
              end
            end

            # Ignore the job/release properties not declared as a
            # template. These are used with their defaults, or our
            # opinions. They cannot change and have no parameters.
            next unless templates[pname]

            parameters.push(*templates[pname])
          end
        end
      end
      definition[role['name']] = parameters.uniq.sort.join("\\|")
    end
  end

  def process_templates(rolemanifest, role)
    return unless rolemanifest['configuration'] && rolemanifest['configuration']['templates']

    templates = {}
    rolemanifest['configuration']['templates'].each do |property, template|
      templates[property] = Common.parameters_in_template(template)
    end

    if role['configuration'] && role['configuration']['templates']
      role['configuration']['templates'].each do |property, template|
        templates[property] = Common.parameters_in_template(template)
      end
    end

    templates
  end

  # # ## ### ##### ########
end

# # ## ### ##### ########
