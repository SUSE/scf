#!/usr/bin/env ruby

## Explanations and overview:

## This test does a lot of setup to determine that the universal
## service broker (cf-usb) is actually working.
#
## 0. A domain for TCP routing is created, to connect all the pieces.
#
## 1. A local server is started as an app and made available
##    through cf TCP routing.  The test-specific class determines how the server
##    will be started.
#
## 2. The sidecar is started as an app, configured to talk to the server from
##    the first step.
#
## 3. The cf-usb is configured to talk to and use the sidecar.
#
## 4. Then we can check that the appropriate service appears in the marketplace,
##    create a service from it, and check that this service is viewable too.
#
## In the code below these phases are marked with "--(N)--" where N is
## the step number.
#
## Note, the applications of step 1 and 2 are docker apps. This is why
## the `pre-start.sh` script enables the `diego_docker` feature-flag
## of CF. For step (3) the `pre-start.sh` script extended the `cf`
## client with the `cf-usb-plugin` plugin.

require_relative 'testutils'
require 'json'

class CFUSBTestBase
    MYSQL_USER = 'root'
    MYSQL_PASS = 'testpass'

    # Return the TCP domain to use (as the FQDN).  Creates it if it does not
    # already exist, also setting up the teardown as necessary.
    def tcp_domain
        return @tcp_domain unless @tcp_domain.nil?
        tcp_domain = ENV.fetch('CF_TCP_DOMAIN', random_suffix('tcp') + ENV['CF_DOMAIN'])
        at_exit do
            set errexit: false do
                run "cf delete-shared-domain -f #{tcp_domain}"
            end
        end
        set errexit: false do
            run "cf delete-shared-domain -f #{tcp_domain}"
        end
        run "cf create-shared-domain #{tcp_domain} --router-group default-tcp"
        run "cf update-quota default --reserved-route-ports -1"
        @tcp_domain = tcp_domain
    end

    def tmpdir
        @tmpdir ||= mktmpdir
    end

    def sidecar_api_key
        @sidecar_api_key ||= random_suffix('secret-key')
    end

    def get_port(app_name, domain_name)
        app_guid = capture("cf app #{app_name} --guid").chomp
        routes = cf_curl("/v2/apps/#{app_guid}/routes?inline-relations-depth=1")
        routes['resources'].each do |resource|
            next unless resource['metadata']['url'].start_with? '/v2/routes/'
            next unless resource['entity']['domain']['entity']['name'] == domain_name
            return resource['entity']['port']
        end
        fail "Failed for find TCP port for #{app_name} in domain #{domain_name}"
    end

    def service_port
        @service_port ||= get_port server_app, tcp_domain
    end

    def extra_helm_arguments
        args = []
        %w(hostname username password).each do |param|
            val = ENV["HELM_REGISTRY_#{param.upcase}"]
            next if val.nil?
            args << '--set' << "kube.registry.#{param}=#{val}"
        end
        args
    end

    # --(0)-- Initialize tcp routing
    def initialize_tcp_routing
        # --(0.1) -- Initialize a security group to allow for inter-app comms
        # Attention: This SG opens the entire internal kube service network.

        secgroup_name = random_suffix('secgroup')
        File.open("#{tmpdir}/internal-services.json", 'w') do |f|
            f.puts [ { destination: '0.0.0.0/0', protocol: 'all' } ].to_json
        end
        at_exit do
            set errexit: false do
                run "cf unbind-running-security-group #{secgroup_name}"
                run "cf unbind-staging-security-group #{secgroup_name}"
                run "cf delete-security-group -f #{secgroup_name}"
            end
        end
        run "cf create-security-group       #{secgroup_name} #{tmpdir}/internal-services.json"
        run "cf bind-running-security-group #{secgroup_name}"
        run "cf bind-staging-security-group #{secgroup_name}"
    end

    ## --(1)-- Create and configure the server
    def deploy_server
        raise NotImplementedError, 'The derived class is expected to implement this'
    end

    ## --(2)-- Create and configure the sidecar for usb.
    def deploy_sidecar
        raise NotImplementedError, 'The derived class is expected to implement this'
    end

    # --(3)-- Create a driver endpoint to the mysql sidecar (== service type)
    def create_driver_endpoint
        at_exit do
            set errexit: false do
                run "yes | cf usb-delete-driver-endpoint #{service_type}"
            end
        end
        # Note that the -c ":" is required as a workaround to a known issue
        run 'cf', 'usb-create-driver-endpoint', service_type,
            "https://#{sidecar_app}.#{ENV['CF_DOMAIN']}",
            sidecar_api_key,
            '-c', ':'
    end

    # --(4)-- Check that the service is available in the marketplace and use it
    def create_service
        ## Note: The commands without grep filtering are useful in case of
        ## failures, providing immediate information about the data which runs
        ## through and fails the filter.

        run "cf marketplace"
        run "cf marketplace | grep #{service_type}"

        at_exit do
            set errexit: false do
                run "cf delete-service -f #{service_instance}"
            end
        end
        run "cf create-service #{service_type} default #{service_instance}"

        run "cf services"
        run "cf services | grep #{service_instance}"
    end

    def deploy_sidecar
        at_exit do
            set errexit: false do
                show_pods_for_namespace helm_namespace
                print_all_container_logs_in_namespace helm_namespace
                run "yes | cf usb-delete-driver-endpoint #{service_type}"
                run "helm delete --purge #{helm_release}"
                run "kubectl delete ns #{helm_namespace}"
                run "kubectl wait --for=delete ns/#{helm_namespace}"
            end
        end

        run 'helm init --client-only'

        values = helm_chart_values.dup
        File.open("#{tmpdir}/helm-values.json", 'w') do |f|
            f.puts({env: values}.to_json)
        end
        # Print out the values used, but filter out the passwords
        values.keys.each { |k| values[k] = '<redacted>' if k.to_s.include? 'PASS' }
        puts values.to_json

        args = %W(helm upgrade #{helm_release}
            --install
            --repo #{helm_repo}
            --namespace #{helm_namespace}
            --wait
            --values #{tmpdir}/helm-values.json
        )
        args += ['--version', helm_version] unless helm_version.empty?
        args += extra_helm_arguments
        args << helm_chart
        run *args
        wait_for_jobs helm_namespace
        wait_for_namespace helm_namespace
        run "kubectl get pods --namespace=#{helm_namespace}"
    end

    def run_test
        use_global_timeout
        login
        setup_org_space

        initialize_tcp_routing
        deploy_server
        deploy_sidecar
        create_service
    end
end
