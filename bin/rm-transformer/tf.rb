# -*- coding: utf-8 -*-
## Terraform output provider
# # ## ### ##### ########

require_relative 'common'
require 'json'

# Provider for terraform declarations derived from a role-manifest.
class ToTerraform < Common
  def initialize(options)
    super(options)
    @have_specials = []
    @out = {}
  end

  # Public API
  def transform(manifest)
    to_terraform(manifest)
    @out.to_json
  end

  # Internal definitions

  def to_terraform(manifest)
    emit_dtr_variables
    emit_loader(manifest)
    emit_settings(manifest)
    emit_list_of_roles(manifest)
    emit_configuration(manifest)
  end

  # Emit a variable definition
  def emit_variable(name, value:nil, desc:nil)
    @out['variable'] ||= {}
    @out['variable'][name] ||= {}
    @out['variable'][name]['description'] = desc unless desc.nil?
    @out['variable'][name]['default'] = value unless value.nil?
  end

  def emit_output(name, value)
    @out['output'] ||= {}
    @out['output'][name] ||= {
      'value' => value
    }
  end

  def emit_null(name, value)
    @out['resource'] ||= []
    @out['resource'] << {
      "null_resource" => {
        name => {
          'triggers' => [
            {
              name => value
            }
          ]
        }
      }
    }
  end

  # High level emitters, HCF specific structures ...

  def emit_configuration(manifest)
    manifest['configuration']['variables'].each do |config|
      name = config['name']
      if special_variables.include?(name)
        @have_specials << name
        next
      end
      value = config['default']
      # Ignore optional values without a default.
      next if value.nil? && !config['required']
      emit_variable(name, value: value)
    end
    missing = special_variables.sort - @have_specials.sort
    missing.each do |var_name|
      STDERR.puts "#{var_name} is missing from input role-manifest"
    end
  end

  def special_variables
    # Special case various RM variables (null_resource). We skip them
    # and expect an external file to provide a null_resource wiring
    # them to the networking setup. Because only the external
    # context knows where the value actually comes from in terms of
    # vars, etc.
    %w(DOMAIN)
  end

  def emit_dtr_variables
    emit_variable('hcf_image_prefix',
                  value: "#{@hcf_prefix}-",
                  desc: 'The prefix to use before the role name to construct the full image name')

    emit_variable('hcf_version',
                  value: @hcf_tag.to_s,
                  desc: 'The image tag of interest')

    emit_variable('docker_trusted_registry',
                  value: @dtr.to_s,
                  desc: 'Location of the trusted registry holding the images to use')

    emit_variable('docker_org',
                  value: @dtr_org.to_s,
                  desc: 'The organization the images belong to')

    emit_variable('docker_username',
                  desc: 'Access to the trusted registry, user to use')

    emit_variable('docker_email',
                  desc: "Access to the trusted registry, the user's email")

    emit_variable('docker_password',
                  desc: "Access to the trusted registry, the user's password")
  end

  def emit_loader(manifest)
    loader = to_names(manifest['roles']).map do |name|
      make_pull_command(name)
    end.reduce(:+)
    emit_null('docker_loader', loader)
  end

  # Construct a docker pull command for the named image/role
  def make_pull_command(name)
    cmd = 'docker pull ${var.docker_trusted_registry}/${var.docker_org}/'
    cmd += '${var.hcf_image_prefix}' + name
    cmd += ':${var.hcf_version}'
    cmd += ' | cat'
    cmd += "\n"
    cmd
  end

  def emit_settings(manifest)
    rm_configuration = ''
    manifest['configuration']['variables'].each do |config|
      # Ignore optional values without a default.
      next if config['default'].nil? && !config['required']
      rm_configuration += make_assignment_for(config['name'])
    end

    emit_null('rm_configuration', rm_configuration)
  end

  # Construct the VAR=VALUE assignment going into the docker env-file
  # later, for the named setting of the role-manifest.
  def make_assignment_for(name)
    # Note, no double-quotes around any values. Would become part of
    # the value when docker run read the --env-file. Bad.
    if special_variables.include? name
      %(#{name}=\$\{null_resource.#{name}.triggers.#{name}\}\n)
    else
      %(#{name}=\$\{replace(var.#{name},"\\\\n", "\\\\\\\\n")\}\n)
      # In the hcf.tf this becomes replace(XXX,"\n", "\\\\n")
      # The replacement string looks like "....\\n....".
      # The echo saving this into the final .env file makes this
      # "...\n..."
      # And docker sees the '\n" and makes it a proper EOL character
      # in the value of the variable.
      #
      # TODO: Check if TF can generate a local file, with less
      # levels of quoting involved.
    end
  end

  def emit_list_of_roles(manifest)
    emit_variable('all_the_roles',
                  value: to_names(get_job_roles(manifest) +
                                  get_task_roles(manifest)).join(' '))
    emit_variable('all_the_jobs',
                  value: to_names(get_job_roles(manifest)).join(' '))
    emit_variable('all_the_tasks',
                  value: to_names(get_task_roles(manifest)).join(' '))
  end

  def get_job_roles(manifest)
    manifest['roles'].select { |role| job?(role) }
  end

  def get_task_roles(manifest, stage: nil)
    tasks = manifest['roles'].select { |role| task?(role) && !skip_manual?(role) }
    tasks.select! { |role| flight_stage_of(role) == stage } unless stage.nil?
    tasks
  end

  def to_names(roles)
    roles.map { |role| role['name'] }
  end

  def get_exposed_ports(roles)
    result = [ ssh_port ]

    roles.each do |role|
      # Skip everything without runtime data or ports
      next unless role['run']
      next unless role['run']['exposed-ports']
      next if     role['run']['exposed-ports'].empty?

      role['run']['exposed-ports'].each do |port|
        # Skip all internal ports
        next unless port['public']
        result.push(port)
      end
    end

    result
  end

  def ssh_port
    {
      'name'        => 'ssh',
      'protocol'    => 'tcp',
      'external'    => 22,
      'internal'    => 22,
      'public'      => true
    }
  end

  # # ## ### ##### ########
end

# # ## ### ##### ########
