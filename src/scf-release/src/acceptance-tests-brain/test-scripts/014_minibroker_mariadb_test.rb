#!/usr/bin/env ruby

require_relative 'minibroker_helper'

$DB_NAME = random_suffix('db')

tester = MiniBrokerTest.new('mariadb', '3306')
tester.service_params = {
    db: { name: $DB_NAME },
    mariadbDatabase: $DB_NAME
    # Need "mariadbDatabase" key for compatibility with old minibroker
}
tester.run_test do |tester|
    CF_APP = random_suffix('app', 'CF_APP')

    at_exit do
        set errexit: false do
            run "cf logs --recent #{CF_APP}"
            run "cf env #{CF_APP}"
            run "cf unbind-service #{CF_APP} #{tester.service_instance}"
            run "cf delete -f #{CF_APP}"
        end
    end

    run "cf push #{CF_APP} --no-start -p #{resource_path('pong_matcher_go')}"
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
    app_url = "http://#{app_host}.#{app_domain}"

    run "cf env #{CF_APP}"
    run "curl -v --fail -X DELETE #{app_url}/all"
    run %Q@curl -v --fail -H 'Content-Type: application/json' -X PUT #{app_url}/match_requests/firstrequest -d '{"player": "one"}'@
    run %Q@curl -v --fail -H 'Content-Type: application/json' -X PUT #{app_url}/match_requests/secondrequest -d '{"player": "two"}'@
    run "curl -v --fail -X GET #{app_url}/match_requests/firstrequest"
end
