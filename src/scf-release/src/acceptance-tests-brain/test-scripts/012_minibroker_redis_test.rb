#!/usr/bin/env ruby

require_relative 'minibroker_helper'

MiniBrokerTest.new('redis', '6379').run_test do |tester|
    CF_APP = random_suffix('app', 'CF_APP')

    at_exit do
        set errexit: false do
            run "cf unbind-service #{CF_APP} #{tester.service_instance}"
            run "cf delete -f #{CF_APP}"
        end
    end

    run "cf push #{CF_APP} --no-start -p #{resource_path('cf-redis-example-app')}"
    run "cf bind-service #{CF_APP} #{tester.service_instance}"
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

    run "curl -v -X PUT http://#{app_host}.#{app_domain}/hello -d data=success"
    output = capture("curl -v http://#{app_host}.#{app_domain}/hello")
    fail "Incorrect output: got #{output.inspect}" unless output == 'success'
end
