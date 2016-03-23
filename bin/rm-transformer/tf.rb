# -*- coding: utf-8 -*-
## Terraform output provider
# # ## ### ##### ########

require_relative 'common'

# Provider for terraform declarations derived from a role-manifest.
# Takes additional files containing the execution context.
class ToTerraform < Common
  def initialize(options, remainder)
    super(options)
    @have_public_ip = false
    @have_domain = false
    initialize_emitter_state
    copy_addons(remainder)
  end

  def initialize_dtr_information
    # Get options, set defaults for missing parts
    @dtr         = @options[:dtr] || 'docker.helion.lol'
    @dtr_org     = @options[:dtr_org] || 'helioncf'
    @hcf_version = @options[:hcf_version] || 'develop'
    @hcf_prefix  = @options[:hcf_prefix] || 'hcf'
  end

  def initialize_emitter_state
    @out = ['# © Copyright 2015 Hewlett Packard Enterprise Development LP', '']
    @secnumber = 1
    @level     = 0
  end

  def copy_addons(paths)
    # Process the add-on files first. Pass them into the output, unchanged.
    paths.each do |path|
      emit_header(path)
      emit(open(path).read)
    end
  end

  # Public API
  def transform(manifest)
    hdr = '# # ## ### ##### Generated parts starting here ##### ### ## # #'
    emit_header(hdr)
    to_terraform(manifest)
    @out.join("\n")
  end

  # Internal definitions

  def to_terraform(manifest)
    emit_dtr_variables
    emit_loader(manifest)
    emit_settings(manifest)
    emit_list_of_roles(manifest)
    emit_configuration(manifest)
    emit_header 'Done'
  end

  # Low level emitter management, individual lines, indentation control

  def emit(text)
    @out.push('    ' * @level + text)
  end

  def indent
    @level += 1
    yield
    @level -= 1
  end

  def block(text)
    emit("#{text} {")
    indent do
      yield
    end
    emit('}')
    emit('') if @level == 0
  end

  # Mid level emitters. Basic TF structures.

  def emit_header(text)
    emit('# # ## ###')
    emit("## Section #{@secnumber}: #{text}")
    emit('')
    @secnumber += 1
  end

  def tf_quote(text)
    text.gsub('"', '\\"')
  end

  def emit_variable(name, value:nil, desc:nil)
    # Quote the double-quotes in the value to satisfy tf syntax.
    block %(variable "#{name}") do
      emit(%(description = "#{desc}")) unless desc.nil?
      emit(%(default = "#{tf_quote(value)}")) unless value.nil?
    end
  end

  def emit_output(name, value)
    block %(output "#{name}") do
      emit(%(value = "#{tf_quote(value)}"))
    end
  end

  def emit_null(name, value)
    marker = '<' + '<' + 'EOF'
    # Written as above to avoid emacs miscoloring of all
    # following lines, it does not like << in the string.
    # Likely thinks that a ruby here document begins.
    # Reuse name for both resource and trigger variable.
    block %(resource "null_resource" "#{name}") do
      block 'triggers =' do
        emit("#{name} = #{marker}\n#{value}EOF")
      end
    end
  end

  def emit_null_simple(name, value)
    block %(resource "null_resource" "#{name}") do
      block 'triggers =' do
        emit(%(#{name} = "#{tf_quote(value)}"))
      end
    end
  end

  # High level emitters, HCF specific structures ...

  def emit_configuration(manifest)
    emit_header 'Role manifest configuration variables'
    manifest['configuration']['variables'].each do |config|
      name = config['name']
      next if special?(name)
      value = config['default']
      emit_variable(name, value: value)
    end
    puts 'PUBLIC_IP is missing from input role-manifest' unless @have_public_ip
    puts 'DOMAIN is missing from input role-manifest' unless @have_domain
  end

  def special?(name)
    # Special case two RM variables (null_resource). We skip them
    # and expect an external file to provide a null_resource wiring
    # them to the networking setup. Because only the external
    # context knows where the value actually comes from in terms of
    # vars, etc.
    case name
    when 'PUBLIC_IP' then @have_public_ip = true
    when 'DOMAIN'    then @have_domain = true
    else return false
    end
    true
  end

  def emit_dtr_variables
    emit_variable('hcf_image_prefix',
                  value: "#{@hcf_prefix}-",
                  desc: 'The prefix to use before the role name to construct the full image name')

    emit_variable('hcf_version',
                  value: @hcf_version.to_s,
                  desc: 'The image version of interest')

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
    emit_header 'Retrieving docker images for roles'
    emit_null('docker_loader', loader)
  end

  # Construct a docker pull command for the named image/role
  def make_pull_command(name)
    cmd = 'docker pull ${var.docker_trusted_registry}/${var.docker_org}/'
    cmd += '${var.hcf_image_prefix}' + name
    cmd += ':${var.hcf_version}'
    cmd += "\n"
    cmd
  end

  def emit_settings(manifest)
    rm_configuration = ''
    manifest['configuration']['variables'].each do |config|
      rm_configuration += make_assignment_for(config['name'])
    end

    emit_header 'Role configuration'
    emit_null('rm_configuration', rm_configuration)
  end

  # Construct the VAR=VALUE assignment going into the docker env-file
  # later, for the named setting of the role-manifest.
  def make_assignment_for(name)
    # Note, no double-quotes around any values. Would become part of
    # the value when docker run read the --env-file. Bad.
    if name == 'PUBLIC_IP'
      %(#{name}=\$\{null_resource.#{name}.triggers.#{name}\}\n)
    elsif name == 'DOMAIN'
      %(#{name}=\$\{null_resource.#{name}.triggers.#{name}\}\n)
    else
      %(#{name}=\$\{replace(var.#{name},"\\n", "\\\\\\\\n")\}\n)
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
    emit_header 'List of all roles'
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

  # # ## ### ##### ########
end

# # ## ### ##### ########
