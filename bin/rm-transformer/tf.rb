# -*- coding: utf-8 -*-
## Terraform output provider
# # ## ### ##### ########

# Provider for terraform declarations derived from a role-manifest.
# Takes additional files containing the execution context.
class ToTerraform
  def initialize(options, remainder)
    @options = options
    # Get options, set defaults for missing parts
    @dtr         = @options[:dtr] || 'docker.helion.lol'
    @dtr_org     = @options[:dtr_org] || 'helioncf'
    @hcf_version = @options[:hcf_version] || 'develop'
    @hcf_prefix  = @options[:hcf_prefix] || 'hcf'

    @out       = ['# © Copyright 2015 Hewlett Packard Enterprise Development LP', '']
    @indent    = ['']
    @secnumber = 1

    # Process the add-on files first. Pass them into the output, unchanged.
    remainder.each do |path|
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
    emit_header('# # ## ### ##### Generated parts starting here ##### ### ## # #')
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
    emit_loader(roles)
    emit_runner(roles)
    emit_settings(roles)
    emit_list_of_roles(roles)
    emit_configuration(roles)
    emit_header 'Done'
  end

  # Low level emitter management, individual lines, indentation control

  def emit(text)
    @out.push(@indent[-1] + text)
  end

  def indent
    @indent.push(@indent.last + ' ' * 4)
    yield
    @indent.pop
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

    emit(%Q|variable "#{name}" {|)
    indent do
      emit(%Q|default = "#{tf_quote(value)}"|)
    end
    emit('}')
    emit('')
  end

  def emit_variable_with_explanation(name, explanation, value)
    emit(%Q|variable "#{name}" {|)
    indent do
      emit(%Q|description = "#{explanation}"|)
      emit(%Q|default = "#{tf_quote(value)}"|)
    end
    emit('}')
    emit('')
  end

  def emit_user_variable_with_explanation(name, explanation)
    emit(%Q|variable "#{name}" {|)
    indent do
      emit(%Q|description = "#{explanation}"|)
    end
    emit('}')
    emit('')
  end

  def emit_output(name, value)
    emit(%Q|output "#{name}" {|)
    indent do
      emit(%Q|value = "#{tf_quote(value)}"|)
    end
    emit('}')
    emit('')
  end

  def emit_null(name, value)
    marker = '<' + '<' + 'EOF'
    # Written as above to avoid emacs miscoloring of all
    # following lines, it does not like << in the string.
    # Likely thinks that a ruby here document begins.
    # Reuse name for both resource and trigger variable.
    emit(%Q|resource "null_resource" "#{name}" {|)
    indent do
      emit('triggers = {')
      indent do
        emit("#{name} = #{marker}\n#{value}EOF")
      end
      emit('}')
    end
    emit('}')
    emit('')
  end

  def emit_null_simple(name, value)
    emit(%Q|resource "null_resource" "#{name}" {|)
    indent do
      emit('triggers = {')
      indent do
        emit(%Q|#{name} = "#{tf_quote(value)}"|)
      end
      emit('}')
    end
    emit('}')
    emit('')
  end

  # High level emitters, HCF specific structures ...

  def emit_configuration(roles)
    emit_header 'Role manifest configuration variables'

    # Global configs become plain tf variables.
    have_pip = false
    have_domain = false
    roles['configuration']['variables'].each do |config|
      name = config['name']
      value = config['default']

      # Special case this RM variable (null_resource). We skip it and
      # and expect an external file to provide a null_resource wiring
      # it to the networking setup. Because only thsi external context
      # knows where the value actually comes from in terms of vars, etc.
      if name == 'PUBLIC_IP'
        have_pip = true
        next
      end
      if name == 'DOMAIN'
        have_domain = true
        next
      end

      emit_variable(name, value)
    end

    puts 'PUBLIC_IP is missing from input role-manifest' unless have_pip
    puts 'DOMAIN is missing from input role-manifest' unless have_domain
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
    run_environment_setup = <<SETUP
# Configuration for run-role.sh, to place logs and state into the data volume

export    HCF_RUN_STORE=${var.runtime_store_directory}
mkdir -p $HCF_RUN_STORE

export    HCF_RUN_LOG_DIRECTORY=${var.runtime_log_directory}
mkdir -p $HCF_RUN_LOG_DIRECTORY

SETUP
    envdir = '${var.fs_host_root}/opt/hcf/etc'

    runner_jobs = run_environment_setup
    runner_tasks = run_environment_setup

    roles['roles'].each do |role|
      name = role['name']
      type = role['type'] || 'bosh'

      next if type == 'docker'

      runcmd = "${var.fs_host_root}/opt/hcf/bin/run-role.sh #{envdir} "
      runcmd += name
      runcmd += ' --restart=always'

      if type == 'bosh-task'
        # Ignore dev parts by default.
        next if role['dev-only'] && !@options[:dev]
        runner_tasks += runcmd + "\n"
        next
      end

      runner_jobs += runcmd + "\n"
    end

    emit_header 'Running of job roles'
    emit_null('runner_jobs', runner_jobs)

    # Running of task roles
    emit_header 'NOT USED YET - TODO - Change to suit actual invokation of tasks'
    emit_null('runner_tasks', runner_tasks)
  end

  def emit_settings(roles)
    rm_configuration = ''
    roles['configuration']['variables'].each do |config|
      name = config['name']

      # Note, no double-quotes around any values. Would become part of
      # the value when docker run read the --env-file. Bad.
      if name == 'PUBLIC_IP'
        assignment = %Q|#{name}=\$\{null_resource.#{name}.triggers.#{name}\}\n|
      elsif name == 'DOMAIN'
        assignment = %Q|#{name}=\$\{null_resource.#{name}.triggers.#{name}\}\n|
      else
        assignment = %Q|#{name}=\$\{replace(var.#{name},"\\n", "\\\\\\\\n")\}\n|
        # In the hcf.tf this becomes replace(XXX,"\n", "\\\\n")
        # The replacement string looks like "....\\n....".
        # The echo saving this into the final .env file makes this "...\n..."
        # And docker sees the '\n" and makes it a proper EOL character in the value
        # of the variable.
        #
        # TODO: Check if TF can generate a local file, with less levels of quoting involved.
      end

      # Collect assignments for the aggregate variable, see below.
      rm_configuration += assignment
    end

    emit_header 'Role configuration'
    emit_null('rm_configuration', rm_configuration)
  end

  def emit_list_of_roles(roles)
    emit_header 'List of all roles'

    the_roles = []; # all roles, be they job or task
    the_tasks = []; # only task roles - once-off
    the_jobs  = []; # only job roles  - cont. running

    roles['roles'].each do |role|
      name = role['name']
      type = role['type'] || 'bosh'

      next if type == 'docker'

      the_roles.push(name)

      if type == 'bosh-task'
        # Ignore dev parts by default.
        next if role['dev-only'] && !@options[:dev]
        the_tasks.push(name)
        next
      end

      the_jobs.push(name)
    end

    emit_variable('all_the_roles', the_roles.join(' '))
    emit_variable('all_the_jobs',  the_jobs.join(' '))
    emit_variable('all_the_tasks', the_tasks.join(' '))
  end
end

# # ## ### ##### ########
