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

# We have some waits in this test, and want to clean things up properly
# (especially the service broker) when we abort.  So we wrap a timeout so that
# we get a minute to do any cleanup we need.
Timeout::timeout(ENV.fetch('TESTBRAIN_TIMEOUT', '600').to_i - 60) do
    SCF_LOG_HOST = ENV.fetch('SCF_LOG_HOST', '')
    SCF_LOG_PORT = ENV.fetch('SCF_LOG_PORT', '514')
    SCF_LOG_PROTOCOL = ENV.fetch('SCF_LOG_PROTOCOL', 'tcp')
    if SCF_LOG_HOST.empty?
        message = "SCF_LOG_HOST not set"
        STDERR.puts "\e[0;1;31m#{message}\e[0m"
        show_env
        fail message
    end

    $KUBERNETES_NAMESPACE = ENV['KUBERNETES_NAMESPACE']

    KUBERNETES_DOMAIN_SUFFIX = ".#{$KUBERNETES_NAMESPACE}.svc.#{ENV['KUBERNETES_CLUSTER_DOMAIN']}"
    unless SCF_LOG_HOST.end_with? KUBERNETES_DOMAIN_SUFFIX
        message = "SCF_LOG_HOST (#{SCF_LOG_HOST}) does not end with cluster domain (#{KUBERNETES_DOMAIN_SUFFIX})"
        STDERR.puts "\e[0;1;31m#{message}\e[0m"
        show_env
        fail message
    end

    $LOG_SERVICE_NAME = SCF_LOG_HOST[0...-KUBERNETES_DOMAIN_SUFFIX.length]

    # Report progress to the user; use as printf.
    def status(fmt, *args)
        printf "\n\e[0;32m#{fmt}\e[0m\n", *args
    end

    # Report problem to the user; use as printf.
    def trouble(fmt, *args)
        printf "\n\e[0;31m#{fmt}\e[0m\n", *args
    end

    $RUN_SUFFIX = SecureRandom.hex(8)
    # hex doubles output -> 16 characters.

    # (A) Start emitting logs as soon as possible to maximize the
    # chance the cron task picks up new logs.
    def emit_log_entries
        log_file = "/var/vcap/sys/log/cloud_controller_ng/brains-#{$RUN_SUFFIX}.log"
        cmd = "kubectl exec --namespace #{$KUBERNETES_NAMESPACE} api-group-0 -c api-group --stdin -- tee -a #{log_file}"
        STDERR.puts "Emitting log entries to #{log_file}"
        loop do
            message = "Hello from #{$0} @ #{Time.now}: #{$LOG_SERVICE_NAME}.#{$RUN_SUFFIX}"
            run_with_status("echo #{message} | #{cmd} > /dev/null", xtrace: false)
            sleep 1
        end
    end
    Thread.new{ emit_log_entries }.abort_on_exception = true

    IN_CONTAINER = "kubectl exec --namespace #{$KUBERNETES_NAMESPACE} api-group-0 --container api-group --"

    $succeeded = false
    $pod_name = ""
    at_exit do
        set errexit: false do
            unless $succeeded || $pod_name.empty?
                run "kubectl get --namespace #{$KUBERNETES_NAMESPACE} #{$pod_name}"
                run "kubectl get --namespace #{$KUBERNETES_NAMESPACE} #{$pod_name} -o yaml"
                run "kubectl logs --namespace #{$KUBERNETES_NAMESPACE} #{$pod_name}"
            end

            run "#{IN_CONTAINER} find /var/vcap/sys/log/cloud_controller_ng/ -iname 'brains-*.log' -a -printf '%s %P\n'"
            run "#{IN_CONTAINER} find /var/vcap/sys/log/cloud_controller_ng/ -iname 'brains-*.log' -a -exec cat '{}' ';'"
            run "#{IN_CONTAINER} find /var/vcap/sys/log/cloud_controller_ng/ -iname 'brains-*.log' -a -print -a -delete"
            run "#{IN_CONTAINER} find /etc/rsyslog.d -iname '*-vcap-brains-*.conf' -a -print -a -delete"
            run "kubectl delete deployment,service --namespace #{$KUBERNETES_NAMESPACE} --now --ignore-not-found #{$LOG_SERVICE_NAME}"
        end
    end

    # (B) Configure and run the log receiver pod.
    image = 'opensuse/leap'
    install_args = "zypper --non-interactive install socat util-linux-systemd"
    socat_args = "/usr/bin/socat #{SCF_LOG_PROTOCOL.upcase}-LISTEN:#{SCF_LOG_PORT},fork 'EXEC:/usr/bin/logger --socket-errors=off --stderr --tag \"\"'"
    cmd = %W(
        kubectl run #{$LOG_SERVICE_NAME}
            --generator=run-pod/v1
            --namespace #{$KUBERNETES_NAMESPACE}
            --command
            --port #{SCF_LOG_PORT}
            --expose
            --image=#{image}
            --labels=brains=#{$LOG_SERVICE_NAME}.#{$RUN_SUFFIX}
            --
            /bin/sh -c
        )
    run(*cmd, "#{install_args} && #{socat_args}") # Run the whole shell command as one thing.

    show_env

    # Wait for the receiver pod to exist.
    run_with_retry 10, 5 do
        run "kubectl get pods --namespace #{$KUBERNETES_NAMESPACE} --selector brains=#{$LOG_SERVICE_NAME}.#{$RUN_SUFFIX} --output=wide"
    end
    # Wait for the receiver pod to be ready.
    loop do
        pod_info = JSON.load capture("kubectl get pods --namespace #{$KUBERNETES_NAMESPACE} --selector brains=#{$LOG_SERVICE_NAME}.#{$RUN_SUFFIX} --output json")
        break if pod_info['items'].all? do |item|
            item['status']['conditions']
                .select { |condition| condition['type'] == 'Ready' }
                .all? { |condition| condition['status'] == 'True' }
        end
        sleep 5
    end

    # (C) And check that the messages generates by (A) are reaching the receiver (B).

    # Find the name of the receiver pod, so we can see its logs.
    $pod_name = capture("kubectl get pods --namespace #{$KUBERNETES_NAMESPACE} --selector brains=#{$LOG_SERVICE_NAME}.#{$RUN_SUFFIX} --output=name")

    run "kubectl logs --follow --namespace #{$KUBERNETES_NAMESPACE} #{$pod_name} | grep --line-buffered --max-count=1 #{$LOG_SERVICE_NAME}.#{$RUN_SUFFIX}"

    $succeeded = true
end
