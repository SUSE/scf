#!/usr/bin/env ruby

require_relative 'testutils'
require 'json'
require 'timeout'

login
setup_org_space

CF_SEC_GROUP = random_suffix('sec-group', 'CF_SEC_GROUP')
CF_BROKER = random_suffix('minibroker', 'CF_BROKER')
CF_APP = random_suffix('app', 'CF_APP')
CF_SERVICE = random_suffix('service', 'CF_SERVICE')
MINIBROKER_REPO = ENV.fetch('MINIBROKER_REPO', 'https://minibroker-helm-charts.s3.amazonaws.com/minibroker-charts/')
KUBERNETES_REPO = ENV.fetch('KUBERNETES_REPO', 'https://minibroker-helm-charts.s3.amazonaws.com/kubernetes-charts/')

HELM_RELEASE = random_suffix('minibroker')
MINIBROKER_NAMESPACE = random_suffix('minibroker')
MINIBROKER_PODS_NAMESPACE = random_suffix('minibroker-pod')

tmpdir = mktmpdir

# We have some waits in this test, and want to clean things up properly
# (especially the service broker) when we abort.  So we wrap a timeout so that
# we get a minute to do any cleanup we need.
Timeout::timeout(ENV.fetch('TESTBRAIN_TIMEOUT', '600').to_i - 60) do
    at_exit do
        set errexit: false do
            run "cf unbind-service #{CF_APP} #{CF_SERVICE}"
            status = run_with_status("cf delete-service -f #{CF_SERVICE}")
            unless status.success?
                run "cf purge-service-instance -f #{CF_SERVICE}"
            end
            run "cf delete -f #{CF_APP}"
            run "cf unbind-security-group #{CF_SEC_GROUP} #{$CF_ORG} #{$CF_SPACE}"
            run "cf delete-security-group -f #{CF_SEC_GROUP}"
            run "cf delete-service-broker -f #{CF_BROKER}"
            status = run_with_status("kubectl get namespace #{MINIBROKER_NAMESPACE}")
            if status.success?
                run "kubectl get pods --namespace #{MINIBROKER_NAMESPACE}"
                run "kubectl get pods --namespace #{MINIBROKER_NAMESPACE} -o yaml"
            end
            run "helm delete --purge #{HELM_RELEASE}"
            run "kubectl delete ClusterRoleBinding minibroker"
            [MINIBROKER_NAMESPACE, MINIBROKER_PODS_NAMESPACE].each do |ns|
                loop do
                    status = run_with_status("kubectl get namespace #{ns} >/dev/null 2>/dev/null")
                    break unless status.success?
                    status = run_with_status("kubectl delete namespace #{ns}")
                    break if status.success?
                end
            end
        end
    end

    run "kubectl get namespace #{MINIBROKER_NAMESPACE} || kubectl create namespace #{MINIBROKER_NAMESPACE}"
    run "helm init --client-only"
    run(*%W(helm upgrade #{HELM_RELEASE} minibroker
        --install
        --repo #{MINIBROKER_REPO}
        --devel
        --reset-values
        --namespace #{MINIBROKER_NAMESPACE}
        --set helmRepoUrl=#{KUBERNETES_REPO}
        --set deployServiceCatalog=false
        --set defaultNamespace=#{MINIBROKER_PODS_NAMESPACE}
        --set kube.registry.hostname=index.docker.io
        --set kube.organization=splatform
        --set image=minibroker:latest
      ))
    wait_for_namespace MINIBROKER_NAMESPACE

    run "cf create-service-broker #{CF_BROKER} user pass http://#{HELM_RELEASE}-minibroker.#{MINIBROKER_NAMESPACE}.svc.cluster.local"
    run "cf enable-service-access redis"
    File.open("#{tmpdir}/secgroup.json", 'w') do |f|
        f.puts [{
            protocol: 'tcp',
            destination: '0.0.0.0/0',
            ports: '6379',
            description: 'Allow redis traffic'}].to_json
    end
    begin
        run "cf create-security-group #{CF_SEC_GROUP} #{tmpdir}/secgroup.json"
    rescue RuntimeError
        run "cat #{tmpdir}/secgroup.json"
        raise
    end
    run "cf bind-security-group #{CF_SEC_GROUP} #{$CF_ORG} #{$CF_SPACE}"

    service_brokers = JSON.load capture("cf curl /v2/service_brokers")
    service_broker = service_brokers['resources'].find do |broker|
        broker['entity']['name'] == CF_BROKER
    end
    broker_guid = service_broker['metadata']['guid']

    service_instances = JSON.load capture("cf curl '/v2/services?q=service_broker_guid:#{broker_guid}&q=label:redis'")
    run "echo '#{service_instances.to_json}' | jq -C ."
    service_guid = service_instances['resources'].find { |service| service['metadata']['guid'] }['metadata']['guid']
    puts "# service GUID: #{service_guid}"
    service_plans = JSON.load capture("cf curl '/v2/services/#{service_guid}/service_plans'")
    run "echo '#{service_plans.to_json}' | jq -C ."
    service_plan_id = service_plans['resources'].first['entity']['name']
    puts "# service plan ID: #{service_plan_id}"

    run "cf create-service redis #{service_plan_id} #{CF_SERVICE}"
    run "cf push #{CF_APP} --no-start -p #{resource_path('cf-redis-example-app')}"
    run "cf bind-service #{CF_APP} #{CF_SERVICE}"
    run "cf start #{CF_APP}"
    app_guid = capture("cf app #{CF_APP} --guid")
    puts "# app GUID: #{app_guid}"
    run_with_retry 60, 10 do
        app_info = JSON.load capture("cf curl '/v2/apps/#{app_guid}'")
        break if app_info['entity']['state'] == 'STARTED'
    end

    route_mappings = JSON.load capture("cf curl '/v2/apps/#{app_guid}/route_mappings'")
    run "echo '#{route_mappings.to_json}' | jq -C ."
    route_url = route_mappings['resources'].map{ |resource| resource['entity']['route_url'] }.reject(&:nil?).reject(&:empty?).first
    puts "# Route URL: #{route_url}"
    route_info = JSON.load capture("cf curl #{route_url}")
    run "echo '#{route_info.to_json}' | jq -C ."
    app_host = route_info['entity']['host']
    domain_url = route_info['entity']['domain_url']
    domain_info = JSON.load capture("cf curl #{domain_url}")
    run "echo '#{domain_info.to_json}' | jq -C ."
    app_domain = domain_info['entity']['name']

    run "curl -X PUT http://#{app_host}.#{app_domain}/hello -d data=success"
    output = capture("curl http://#{app_host}.#{app_domain}/hello")
    fail "Incorrect output" unless output == 'success'
end
