#!/usr/bin/env ruby

require 'tempfile'

class CalledProcessError < RuntimeError ; end

def run_processs(*args)
  puts args.map(&:to_s).join(' ')
  status = Process.wait2(Process.spawn(*args)).last
  return if status.success?
  raise CalledProcessError, "Failed to run #{args.join(' ')}: #{status.exitstatus}"
end

def setup_environment
  open('/environ', 'r') do |env_file|
    env_file.each_line("\0") do |line|
      line.chomp! "\0"
      name, value = line.split('=', 2)
      if ['DOCKER_USERNAME', 'DOCKER_PASSWORD', 'DOCKER_EMAIL'].include? name
        ENV[name] = value unless value.empty?
        next
      end
      ENV[name] = value if name.start_with? 'OS_'
    end
  end
end

class TerraformTester
  def top_src_dir
    @top_src_dir ||= File.dirname(File.dirname(File.absolute_path(__FILE__))) 
  end

  def overrides_path
    return @overrides_file.path unless @overrides_file.nil?
    @overrides_file = Tempfile.new(['overrides', '.tfvars'])
    at_exit { @overrides_file.close! }
    @overrides_file.path
  end

  def ensure_overrides_file
    open(overrides_path, 'w') do |file|
      file.write <<-EOF
        openstack_keypair = "#{ENV['OS_SSH_KEYPAIR']}"
        key_file = "#{ENV['OS_SSH_KEY_PATH']}"

        openstack_availability_zone = "nova"
        openstack_network_id = "#{ENV['OS_NETWORK_ID']}"
        openstack_network_name = "#{ENV['OS_NETWORK_NAME']}"
        openstack_region = "#{ENV['OS_REGION_NAME']}"

        docker_username = "#{ENV['DOCKER_USERNAME']}"
        docker_password = "#{ENV['DOCKER_PASSWORD']}"
        docker_email = "#{ENV['DOCKER_EMAIL']}"
      EOF
    end
  end

  def run
    ENV['DOCKER_EMAIL'] ||= 'nobody@example.invalid'

    Dir.chdir top_src_dir

    ensure_overrides_file
    at_exit do
      begin
        run_processs '/usr/local/bin/terraform', 'destroy', '-force', "-var-file=#{overrides_path}"
      rescue CalledProcessError
        sleep 1
        retry
      end
    end

    run_processs '/usr/local/bin/terraform', 'apply', "-var-file=#{overrides_path}"

  end
end

def main
  setup_environment
  TerraformTester.new.run
end

main
