#!/usr/bin/env ruby
# This script contains helpers for running tests.

require 'date'
require 'fileutils'
require 'json'
require 'open3'
require 'securerandom'
require 'shellwords'
require 'timeout'
require 'tmpdir'

# Global options, similar to shopts.
$opts = { errexit: true, xtrace: true }

NAMESPACE = ENV['KUBERNETES_NAMESPACE']
CLUSTER_DOMAIN = ENV['KUBERNETES_CLUSTER_DOMAIN']

def storage_class
    $storage_class ||= ENV['KUBERNETES_STORAGE_CLASS_PERSISTENT']
    return $storage_class if $storage_class && !$storage_class.empty?
    storage_classes = JSON.parse(capture('kubectl get storageclass --output=json'))
    default_storage_class = storage_classes['items'].find do |storage_class|
        storage_class.fetch('metadata', {})
            .fetch('annotations', {})
            .fetch('storageclass.kubernetes.io/is-default-class', 'false') == 'true'
    end
    $storage_class = default_storage_class['metadata']['name'] || 'persistent'
end

# Set global timeout for cleanup; an exception will be triggered the given
# number of seconds before the runner-level timeout expires.
def use_global_timeout(shutdown_time=60)
    main_thread = Thread.current
    main_thread.abort_on_exception = true
    timeout_thread = Thread.new do
        sleep_duration = ENV.fetch('TESTBRAIN_TIMEOUT', '600').to_i - shutdown_time
        begin
            sleep sleep_duration
        rescue => e
            # Main thread terminated or other unexpected exception
            main_thread.raise e
        else
            # Timeout reached
            STDERR.puts "\e[0;1;31mGlobal timeout triggered at #{DateTime.now}\e[0m"
            main_thread.raise Timeout::Error, "timeout reached after #{sleep_duration} seconds"
        end
    end
    at_exit do
        begin
            timeout_thread.kill
            timeout_thread.join
        rescue => e
            # Ignore any errors trying to shut down the timeout thread
        end
    end
end

# Set global options.  If a block is given, the options are only active in that
# block.
def set(opts={})
    if block_given?
        old_opts = $opts.dup
        $opts.merge! opts
        yield
        $opts.merge! old_opts
    else
        $opts.merge! opts
    end
end

# Append a random suffix to a string.  If a second argument is given, the prefix
# is overridden by the given string.
def random_suffix(name, env_var=nil)
    return "#{name}-#{SecureRandom.hex(2)}" if env_var.nil?
    "#{ENV.fetch(env_var, name)}-#{SecureRandom.hex(2)}"
end

# Internal helper: print a command line in the log.
def _print_command(*args)
    cmd = args.dup
    cmd.shift if cmd.first.is_a? Hash
    cmd.pop if cmd.last.is_a? Hash
    opts = $opts.dup
    opts.merge! args.last if args.last.is_a? Hash
    STDERR.puts "#{c_bold}+ #{cmd.join(" ")}#{c_reset}" if opts[:xtrace]
    STDERR.flush
end

# Run the given command line, and return the exit status (as a Process::Status).
def run_with_status(*args)
    _print_command(*args)
    args.last.delete :errexit if args.last.is_a? Hash
    args.last.delete :xtrace if args.last.is_a? Hash
    pid = Process.spawn(*args)
    return Process.wait2(pid).last
end

# Run the given command line.  If errexit is set, an error is raised on failure.
def run(*args)
    opts = $opts.dup
    opts.merge! args.last if args.last.is_a? Hash
    status = run_with_status(*args)
    return unless opts[:errexit]
    unless status.success?
        # Print an error at the failure site
        puts "#{c_red}Command exited with #{status.exitstatus}#{c_reset}"
        fail "Command exited with #{status.exitstatus}"
    end
end

# Run the given command line, and return the standard output as well as the exit
# status (as a Process::Status).
def capture_with_status(*args)
    _print_command(*args)
    args.last.delete :errexit if args.last.is_a? Hash
    args.last.delete :xtrace if args.last.is_a? Hash
    stdout, status = Open3.capture2(*args)
    return stdout.chomp, status
end

# Run the given command line, and return the standard output.
# If errexit is set, an error is raised on failure.
def capture(*args)
    opts = $opts.dup
    opts.merge! args.last if args.last.is_a? Hash
    stdout, status = capture_with_status(*args)
    if opts[:errexit]
        unless status.success?
            # Print an error at the failure site.
            puts "#{c_red}Command exited with #{status.exitstatus}#{c_reset}"
            fail "Command exited with #{status.exitstatus}"
        end
    end
    stdout
end

# Log in to the CF installation under test.
def login
    run "cf api --skip-ssl-validation api.#{ENV['CF_DOMAIN']}"
    run "cf auth #{ENV['CF_USERNAME']} #{ENV['CF_PASSWORD']}"
end

# Set up temporary org / space in the CF installation under test.
# The org / space will be deleted on exit.
# The org name is available as $CF_ORG.
# The space name is available as $CF_SPACE.
def setup_org_space
    $CF_ORG = random_suffix('org', 'CF_ORG')
    $CF_SPACE = random_suffix('space', 'CF_SPACE')
    at_exit do
        set errexit: false do
            run "cf delete-space -f #{$CF_SPACE}"
            run "cf delete-org -f #{$CF_ORG}"
        end
    end
    run "cf create-org #{$CF_ORG}"
    run "cf target -o #{$CF_ORG}"
    run "cf create-space #{$CF_SPACE}"
    run "cf target -s #{$CF_SPACE}"
end

# Return the path to a test resource (in the `test-resources` directory).
def resource_path(*parts)
    File.join(File.dirname(__dir__), 'test-resources', *parts)
end

# Create a temporary directory and return its name.  The directory will be
# deleted when the test exits.
def mktmpdir
    prefix = File.basename($0).sub(/\.rb$/, '-')
    dir = Dir.mktmpdir(prefix)
    at_exit do
        FileUtils.rm_rf dir, secure: true
    end
    dir
end

# Run a block, retrying the given number of times at a given interval
# The block will be retried if a RuntimeError occurs.
def run_with_retry(retries, interval)
    last_error = nil
    retries.times do
        begin
            yield
            return
        rescue RuntimeError => e
            last_error = e
            sleep interval
        end
    end
    fail RuntimeError, "Command failed after #{retries} times: #{last_error}", last_error.backtrace
end

# Poll the status of a Kubernetes namespace, until all the pods in that
# namespace are ready and all the jobs have run.
def wait_for_namespace(namespace, sleep_duration=10)
    loop do
        output = capture("kubectl get pods --namespace #{namespace} --no-headers")
        ready = !output.empty?
        output.each_line do |line|
            name, readiness, status, restarts, age = line.split
            next if status == 'Completed'
            next if status == 'Running' && /^(\d+)\/\1$/ =~ readiness
            puts "# Waiting for: #{line}"
            ready = false
        end
        break if ready
        sleep sleep_duration
    end
end

# Wait for all jobs in a given namespace to succeed
def wait_for_jobs(namespace, delay=10)
    loop do
        success = true
        jobs = capture("kubectl get jobs --namespace=#{namespace} --output=name")
        jobs.split.each do |job|
            status = JSON.load capture("kubectl get --namespace=#{namespace} --output=json #{job}")
            puts status['status'].to_json
            success = false unless status['status']['succeeded']
        end
        break if success
        sleep delay
    end
end

# Wait for the pod to be ready. The timeout is in seconds.
def wait_for_pod_ready(name, namespace, timeout=300)
    run %W(
        kubectl wait pod/#{name}
            --for condition=Ready
            --namespace #{namespace}
            --timeout #{timeout}s
    ).join(" ").chomp
end

# Show the status of a Kubernetes namespace
def show_resources_in_namespace(namespace, *resource_types)
    run "kubectl get #{resource_types.join(','))} --namespace #{namespace} --output-wide"
end

def print_all_container_logs_in_namespace(ns)
    capture("kubectl get pods --namespace #{ns} --output name").split.each do |pod|
        failed = false
        capture("kubectl get --namespace #{ns} #{pod} --output jsonpath='{.spec.containers[*].name}'").split.each do |container|
            status = run_with_status("kubectl logs --namespace #{ns} #{pod} --container #{container}")
            failed ||= !status.success?
        end
        run "kubectl describe --namespace #{ns} #{pod}" if failed
    end
end

# Wait for a cf service asynchronous operation to complete.
def wait_for_async_service_operation(service_instance_name, retries=0)
    service_instance_guid = capture("cf service --guid #{service_instance_name}")
    return { success: false, reason: :not_found } if service_instance_guid == 'FAILED'
    attempts = 0
    loop do
        puts "# Waiting for service instance #{service_instance} to complete operation..."
        service_instance_info = cf_curl("/v2/service_instances/#{service_instance_guid}")
        return { success: true } unless service_instance_info['entity']
        return { success: true } unless service_instance_info['entity']['last_operation']
        return { success: true } unless service_instance_info['entity']['last_operation']['state']
        state = service_instance_info['entity']['last_operation']['state']
        return { success: true } if state != 'in progress'
        return { success: false, reason: :max_retries } if attempts >= retries
        sleep 5
        attempts += 1
    end
end

# Run `cf curl` and return the JSON result.
def cf_curl(*args)
    output = capture('cf', 'curl', *args)
    JSON.parse output
end

def wait_for_statefulset(namespace, statefulset, sleep_duration=10)
    loop do
        break if statefulset_ready(namespace, statefulset)
        sleep sleep_duration
    end
end

# Check if a statefulset is ready or not.
def statefulset_ready(namespace, statefulset)
    if namespace.nil? || namespace.strip.empty?
        fail RuntimeError, "namespace must be set"
    end
    if statefulset.nil? || statefulset.strip.empty?
        fail RuntimeError, "statefulset must be set"
    end
    args = %W(kubectl get statefulset --namespace=#{namespace} #{statefulset})
    desired, status = capture_with_status(*args, '--output=go-template={{or .spec.replicas 0}}')
    return false unless status.success?
    actual, status = capture_with_status(*args, '--output=go-template={{or .status.readyReplicas 0}}')
    return false unless status.success?
    puts "Statefulset #{namespace}/#{statefulset}: #{actual}/#{desired} ready"

    return false unless desired.to_i > 0
    actual.to_i == desired.to_i
end

# Exit the test with the code that marks it as skipped.
def exit_skipping_test()
    Process.exit 99
end

def c_bold
  "\e[0;1m"
end

def c_red
  "\e[1;31m"
end

def c_green
  "\e[0;32m"
end

def c_reset
  "\e[0m"
end
