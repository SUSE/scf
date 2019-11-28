#!/usr/bin/env ruby

require_relative 'testutils'
require 'json'
require 'timeout'

module M
    refine Module do
        def attr_lazy(name, &block)
            sym = "@#{name}".to_sym
            self.send(:define_method, name) do
                self.instance_variable_set sym, block.call(self) unless self.instance_variable_defined? sym
                self.instance_variable_get sym
            end
        end
    end
end

using M

# MiniBrokerTest is a helper class to test minibroker-provided services.
# Usage: MiniBrokerTest.new('redis', 6379).run_test { ... }
class MiniBrokerTest
    def initialize(service_type, service_port)
        @service_type = service_type
        @service_port = service_port
        @service_params = {}
    end

    attr_reader :service_type, :service_port
    attr_accessor :service_params
    attr_lazy(:cf_org) { $CF_ORG }
    attr_lazy(:cf_space) { $CF_SPACE }
    attr_lazy(:service_instance) { random_suffix('service', 'CF_SERVICE') }

    attr_lazy(:tmpdir) { mktmpdir }
    attr_lazy(:sec_group) { random_suffix('sec-group', 'CF_SEC_GROUP') }
    attr_lazy(:broker_name) { random_suffix('minibroker', 'CF_BROKER') }
    attr_lazy(:minibroker_repo) { ENV.fetch('MINIBROKER_REPO', 'https://minibroker-helm-charts.s3.amazonaws.com/minibroker-charts/') }
    attr_lazy(:kubernetes_repo) { ENV.fetch('KUBERNETES_REPO', 'https://minibroker-helm-charts.s3.amazonaws.com/kubernetes-charts/') }
    attr_lazy(:helm_release) { random_suffix('minibroker') }
    attr_lazy(:minibroker_namespace) { random_suffix('minibroker') }
    attr_lazy(:minibroker_pods_namespace) { random_suffix('minibroker-pod') }

    attr_lazy(:service_brokers) { JSON.load capture("cf curl /v2/service_brokers") }
    attr_lazy(:service_broker) { |inst| inst.service_brokers['resources'].find { |broker| broker['entity']['name'] == inst.broker_name } }
    attr_lazy(:broker_guid) { |inst| inst.service_broker['metadata']['guid'] }
    attr_lazy(:service_instances) { |inst| JSON.load capture("cf curl '/v2/services?q=service_broker_guid:#{inst.broker_guid}&q=label:#{inst.service_type}'") }
    attr_lazy(:service_guid) { |inst| inst.service_instances['resources'].find { |service| service['metadata']['guid'] }['metadata']['guid'] }
    attr_lazy(:service_plans) { |inst| JSON.load capture("cf curl '/v2/services/#{inst.service_guid}/service_plans'") }
    attr_lazy(:service_plan_id) { |inst| inst.service_plans['resources'].first['entity']['name'] }

    # Run the minibroker test.
    # The MiniBrokerTest instance will be yielded to the given block.
    def run_test
        # We have some waits in this test, and want to clean things up properly
        # (especially the service broker) when we abort.  So we wrap a timeout
        # so that we get a minute to do any cleanup we need.
        Timeout::timeout(ENV.fetch('TESTBRAIN_TIMEOUT', '600').to_i - 60) do
            login
            setup_org_space

            at_exit do
                set errexit: false do
                    unless @success
                        [minibroker_namespace, minibroker_pods_namespace].each do |ns|
                            show_resources_in_namespace ns, 'pods', 'endpoints', 'services'
                            print_all_container_logs_in_namespace ns
                        end
                    end

                    status = run_with_status "cf delete-service -f #{service_instance}"
                    if status.success?
                        status = wait_for_async_service_operation(service_instance, 10)
                        run "cf purge-service-instance -f #{service_instance}" if !status[:success] && status[:reason] != :not_found
                    else
                        run "cf purge-service-instance -f #{service_instance}"
                    end

                    run "cf unbind-security-group #{sec_group} #{cf_org} #{cf_space}"
                    run "cf delete-security-group -f #{sec_group}"
                    run "cf delete-service-broker -f #{broker_name}"
                    status = run_with_status "kubectl get namespace #{minibroker_namespace}"
                    if status.success?
                        run "kubectl get pods --namespace #{minibroker_namespace}"
                        run "kubectl get pods --namespace #{minibroker_namespace} -o yaml"
                    end
                    run "helm delete --purge #{helm_release}"
                    run "kubectl delete ClusterRoleBinding minibroker"

                    # Delete the Minibroker underlying resources namespace.
                    run "kubectl delete namespace #{minibroker_pods_namespace} --wait=false"

                    # Delete the Minibroker namespace.
                    run "kubectl delete namespace #{minibroker_namespace} --wait=false"
                end
            end

            run "kubectl get namespace #{minibroker_namespace} 2> /dev/null || kubectl create namespace #{minibroker_namespace}"
            run "helm init --client-only"
            run_with_retry 30, 5 do
                run(*%W(helm upgrade #{helm_release} minibroker
                    --install
                    --wait
                    --repo #{minibroker_repo}
                    --devel
                    --reset-values
                    --namespace #{minibroker_namespace}
                    --set helmRepoUrl=#{kubernetes_repo}
                    --set deployServiceCatalog=false
                    --set defaultNamespace=#{minibroker_pods_namespace}
                    --set kube.registry.hostname=index.docker.io
                    --set kube.organization=splatform
                    --set image=minibroker:latest
                    --set imagePullPolicy=Always
                ))
            end

            broker_url = "http://#{helm_release}-minibroker.#{minibroker_namespace}.svc.cluster.local"

            run_with_retry 30, 5 do
                run "cf create-service-broker #{broker_name} user pass #{broker_url}" 
            end
            
            run "cf enable-service-access #{service_type}"
            File.open("#{tmpdir}/secgroup.json", 'w') do |f|
                f.puts [{
                    protocol: 'tcp',
                    destination: '0.0.0.0/0',
                    ports: "#{service_port}",
                    description: "Allow #{service_type} traffic"}].to_json
            end
            begin
                run "cf create-security-group #{sec_group} #{tmpdir}/secgroup.json"
            rescue RuntimeError
                run "cat #{tmpdir}/secgroup.json"
                raise
            end
            run "cf bind-security-group #{sec_group} #{cf_org} #{cf_space}"

            run "echo '#{service_instances.to_json}' | jq -C ."
            puts "# service GUID: #{service_guid}"
            run "echo '#{service_plans.to_json}' | jq -C ."
            puts "# service plan ID: #{service_plan_id}"

            File.open("#{tmpdir}/service-params.json", 'w') { |f| f.puts service_params.to_json }
            run "jq -C . #{tmpdir}/service-params.json"
            started_service_creation = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            
            run_with_retry 30, 5 do
                run "cf create-service #{service_type} #{service_plan_id} #{service_instance} -c #{tmpdir}/service-params.json"
            end
            
            status = wait_for_async_service_operation(service_instance, 30)
            unless status[:success]
                failed_service_creation = Process.clock_gettime(Process::CLOCK_MONOTONIC)
                elapsed = failed_service_creation - started_service_creation
                raise "Failed to create service instance #{service_instance} after #{elapsed} seconds."
            end

            puts "#{c_blue}# Show instance...#{c_reset}"
            run "cf service #{service_instance}"

            wait_for_namespace minibroker_pods_namespace

            puts "#{c_bold}# Setup complete, entering user testcase#{c_reset}"
            yield self

            @success = true
        end
    end
end
