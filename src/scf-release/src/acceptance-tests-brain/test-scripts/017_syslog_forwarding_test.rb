#!/usr/bin/env ruby

# Description of the setup for this test case
#
# 1. A separate thread is spawned to generate log messages at a rate
#    of approximately 1 per second, adding these to a new cc-ng log
#    file in the `api-group` pod.
#
#    See `emit_log_entries`, (A).
#
#    It is expected that the syslog machinery of the pod detects the
#    new file and forwards the incoming entries as per the
#    SCF_LOG_... configuration to a receiver. Part of machinery is a
#    cron job running every minute.
#
# 2. The receiver is a new pod created and run by the test case. It
#    uses the brain test image as foundation and installs and runs the
#    necessary commands to receive log messages on the SCF_LOG_PORT,
#    per the SCF_LOG_PROTOCOL. The pod is named after the SCF_LOG_HOST
#    to make it visible to the kube DNS. Received messages are written
#    to stdout, so that `kubectl logs` will see and report them.
#
#    See (B).
#
# 3. Look for the generated messages in the `kubectl logs` of the
#    receiver pod.
#
#    See (C).

require_relative 'testutils'
require 'json'
require 'securerandom'
require 'timeout'

def show_env
    ENV.sort.select { |k, v| k.start_with? 'SCF_LOG_' }.each do |k, v|
        puts "#{k}=#{v}"
    end
end

def emit_log_entries(namespace, log_file, log_message)
    cmd = "kubectl exec --namespace #{namespace} api-group-0 -c api-group --stdin -- tee -a #{log_file}"
    STDERR.puts "Emitting log entries to #{log_file}\n"
    loop do
        run_with_status("echo #{$0} @ #{Time.now}: #{log_message} | #{cmd} > /dev/null", xtrace: false)
        sleep 1
    end
end

def run_receiver_pod(pod_name, namespace, scf_log_protocol, scf_log_port)
    image = 'opensuse/leap'
    install_args = "zypper --non-interactive install socat util-linux-systemd"
    socat_args = "/usr/bin/socat #{scf_log_protocol.upcase}-LISTEN:#{scf_log_port},fork 'EXEC:/usr/bin/logger --socket-errors=off --stderr --tag \\\"\\\"'"
    cmd = %W(
        kubectl run #{pod_name}
            --command
            --generator=run-pod/v1
            --namespace #{namespace}
            --port #{scf_log_port}
            --expose
            --image=#{image}
            --
            /bin/sh -c "#{install_args} && #{socat_args}"
        ).join(" ").chomp
    run(cmd)
end

def run_in_cf_api(namespace, args)
    run %W(
        kubectl exec api-group-0
            --namespace #{namespace}
            --container api-group
            --
            #{args}
    ).join(" ").chomp
end

# We have some waits in this test, and want to clean things up properly
# (especially the service broker) when we abort.  So we wrap a timeout so that
# we get a minute to do any cleanup we need.
Timeout::timeout(ENV.fetch('TESTBRAIN_TIMEOUT', '600').to_i - 60) do
    SCF_LOG_HOST = ENV.fetch('SCF_LOG_HOST', '')
    SCF_LOG_PORT = ENV.fetch('SCF_LOG_PORT', '514')
    SCF_LOG_PROTOCOL = ENV.fetch('SCF_LOG_PROTOCOL', 'tcp')

    KUBERNETES_DOMAIN_SUFFIX = ".#{NAMESPACE}.svc.#{CLUSTER_DOMAIN}"

    if SCF_LOG_HOST.empty?
        message = "SCF_LOG_HOST not set; expected to end with cluster domain (#{KUBERNETES_DOMAIN_SUFFIX})"
        STDERR.puts "\e[0;1;31m#{message}\e[0m"
        show_env
        exit_skipping_test
    end

    unless SCF_LOG_HOST.end_with? KUBERNETES_DOMAIN_SUFFIX
        message = "SCF_LOG_HOST (#{SCF_LOG_HOST}) does not end with cluster domain (#{KUBERNETES_DOMAIN_SUFFIX})"
        STDERR.puts "\e[0;1;31m#{message}\e[0m"
        show_env
        fail message
    end

    POD_NAME = SCF_LOG_HOST[0...-KUBERNETES_DOMAIN_SUFFIX.length]
    RUN_SUFFIX = SecureRandom.hex(16) # HEX doubles output -> 32 characters.

    # The file used as destination for the logs.
    LOG_FILE_BASE_NAME = "brains_syslog_forwarding_#{RUN_SUFFIX}"
    LOG_FILE = "/var/vcap/sys/log/cloud_controller_ng/#{LOG_FILE_BASE_NAME}.log"

    # The message used by the log emitter.
    LOG_MESSAGE = "#{POD_NAME}.#{RUN_SUFFIX}"

    succeeded = false
    at_exit do
        set errexit: false do
            unless succeeded
                run "kubectl get pod --namespace #{NAMESPACE} #{POD_NAME}"
                run "kubectl get pod --namespace #{NAMESPACE} #{POD_NAME} -o yaml"
                run "kubectl logs --namespace #{NAMESPACE} #{POD_NAME}"
            end

            run_in_cf_api(NAMESPACE, "ls -h #{LOG_FILE}")
            run_in_cf_api(NAMESPACE, "cat #{LOG_FILE}")
            run_in_cf_api(NAMESPACE, "rm -rf #{LOG_FILE}")
            run_in_cf_api(NAMESPACE, "find /etc/rsyslog.d -iname '*#{LOG_FILE_BASE_NAME}.conf' -a -print -a -delete")
            run "kubectl delete pod,service --namespace #{NAMESPACE} --wait=false --ignore-not-found #{POD_NAME}"
        end
    end

    # (A) Start emitting logs.
    Thread.new{
        emit_log_entries(NAMESPACE, LOG_FILE, LOG_MESSAGE)
    }.abort_on_exception = true

    # (B) Configure and run the log receiver pod.
    run_receiver_pod(POD_NAME, NAMESPACE, SCF_LOG_PROTOCOL, SCF_LOG_PORT)

    # Wait for the receiver pod to be ready.
    wait_for_pod_ready(POD_NAME, NAMESPACE)

    # (C) Check that the messages generated by (A) are reaching the receiver (B).
    run "kubectl logs #{POD_NAME} --follow --namespace #{NAMESPACE} | grep --line-buffered --max-count=1 #{LOG_MESSAGE}"
    succeeded = true
end
