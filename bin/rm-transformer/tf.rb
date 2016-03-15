# -*- coding: utf-8 -*-
## Terraform output provider
# # ## ### ##### ########

# Provider for terraform declarations derived from a role-manifest.
# Takes additional files containing the execution context.
class ToTerraform
  def initialize(options, remainder)
    @options = options
    @have_public_ip = false
    @have_domain = false
    initialize_dtr_information
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
  def transform(roles)
    to_terraform(roles)
    @out.join("\n")
  end

  # Internal definitions

  def to_terraform(roles)
    hdr = '# # ## ### ##### Generated parts starting here ##### ### ## # #'
    emit_header(hdr)
    emit_dtr_variables
    emit_loader(roles)
    emit_runner(roles)
    emit_settings(roles)
    emit_list_of_roles(roles)
    emit_configuration(roles)
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

  def emit_variable(name, value)
    # Quote the double-quotes in the value to satisfy tf syntax.
    block %(variable "#{name}") do
      emit(%(default = "#{tf_quote(value)}"))
    end
  end

  def emit_variable_with_explanation(name, explanation, value)
    block %(variable "#{name}") do
      emit(%(description = "#{explanation}"))
      emit(%(default = "#{tf_quote(value)}"))
    end
  end

  def emit_user_variable_with_explanation(name, explanation)
    block %(variable "#{name}") do
      emit(%(description = "#{explanation}"))
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

  def emit_configuration(roles)
    emit_header 'Role manifest configuration variables'
    roles['configuration']['variables'].each do |config|
      name = config['name']
      next if special?(name)
      value = config['default']
      emit_variable(name, value)
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
    emit <<API
variable "hcf_image_prefix" {
    description = "The prefix to use before the role name to construct the full image name"
    default = "#{@hcf_prefix}-"
}

variable "hcf_version" {
    description = "The image version of interest"
    default = "#{@hcf_version}"
}

variable "docker_trusted_registry" {
    description = "Location of the trusted registry holding the images to use"
    default = "#{@dtr}"
}

variable "docker_org" {
    description = "The organization the images belong to"
    default = "#{@dtr_org}"
}

variable "docker_username" {
    description = "Access to the trusted registry, user to use"
}

variable "docker_email" {
    description = "Access to the trusted registry, the user's email"
}

variable "docker_password" {
    description = "Access to the trusted registry, the user's password"
}
API
  end

  def emit_loader(roles)
    loader = ''
    roles['roles'].each do |role|
      name = role['name']

      rload = 'docker pull ${var.docker_trusted_registry}/${var.docker_org}/'
      rload += '${var.hcf_image_prefix}' + name
      rload += ':${var.hcf_version}'

      loader += rload + "\n"
    end

    emit_header 'Retrieving docker images for roles'
    emit_null('docker_loader', loader)
  end

  def emit_runner(roles)
    emit_jobs(roles)
    emit_tasks(roles)
  end

  def emit_jobs(roles)
    runner_jobs = run_environment_setup

    roles['roles'].each do |role|
      type = role['type'] || 'bosh'

      next if type == 'docker' || type == 'bosh-task'

      runner_jobs += make_run_cmd_for(role['name'])
    end

    emit_header 'Running of job roles'
    emit_null('runner_jobs', runner_jobs)
  end

  def emit_tasks(roles)
    runner_tasks = run_environment_setup

    roles['roles'].each do |role|
      type = role['type'] || 'bosh'

      next if type == 'docker' ||
              type == 'bosh' ||
              (role['dev-only'] && !@options[:dev])
      # type == bosh-task now

      runner_tasks += make_run_cmd_for(role['name'])
    end

    emit_header 'NOT USED YET - TODO - Change to suit actual invokation'
    emit_null('runner_tasks', runner_tasks)
  end

  # Construct the command used in the host to start the named role.
  def make_run_cmd_for(name)
    cmd = "${var.fs_host_root}/opt/hcf/bin/run-role.sh #{run_environment_path} "
    cmd += name
    cmd += ' --restart=always'
    cmd += "\n"
    cmd
  end

  def run_environment_path
    '${var.fs_host_root}/opt/hcf/etc'
  end

  def run_environment_setup
    <<SETUP
# Configuration for run-role.sh, to place logs and state into the data volume

export    HCF_RUN_STORE=${var.runtime_store_directory}
mkdir -p $HCF_RUN_STORE

export    HCF_RUN_LOG_DIRECTORY=${var.runtime_log_directory}
mkdir -p $HCF_RUN_LOG_DIRECTORY

SETUP
  end

  def emit_settings(roles)
    rm_configuration = ''
    roles['configuration']['variables'].each do |config|
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

  def emit_list_of_roles(roles)
    emit_header 'List of all roles'
    emit_list_of_all_roles(roles)
    emit_list_of_job_roles(roles)
    emit_list_of_task_roles(roles)
  end

  def emit_list_of_all_roles(roles)
    the_roles = []
    roles['roles'].each do |role|
      type = role['type'] || 'bosh'

      next if type == 'docker' ||
              (type == 'bosh-task' &&
               role['dev-only'] &&
               !@options[:dev])

      the_roles.push(role['name'])
    end

    emit_variable('all_the_roles', the_roles.join(' '))
  end

  def emit_list_of_job_roles(roles)
    the_jobs = []

    roles['roles'].each do |role|
      type = role['type'] || 'bosh'
      next if type == 'docker' || type == 'bosh-task'

      the_jobs.push(role['name'])
    end

    emit_variable('all_the_jobs', the_jobs.join(' '))
  end

  def emit_list_of_task_roles(roles)
    the_tasks = []

    roles['roles'].each do |role|
      type = role['type'] || 'bosh'
      next if type == 'docker' ||
              type == 'bosh' ||
              (role['dev-only'] && !@options[:dev])

      the_tasks.push(role['name'])
    end

    emit_variable('all_the_tasks', the_tasks.join(' '))
  end
end

# # ## ### ##### ########
