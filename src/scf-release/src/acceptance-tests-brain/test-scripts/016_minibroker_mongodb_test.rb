#!/usr/bin/env ruby

require_relative 'minibroker_helper'

tester = MiniBrokerTest.new('mongodb', '27017')
tester.service_params = {
    image: { debug: true },
    livenessProbe: { enabled: false },
    mongodbDatabase: random_suffix('database'),
    mongodbUsername: random_suffix('user'),
    mongodbPassword: random_suffix('pass'),
    persistence: { storageClass: STORAGE_CLASS },
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

    # Create an app bound to the service under test, and start it.
    run "cf push #{CF_APP} --no-start -p #{resource_path('python-mongodb-blog')}"
    run "cf bind-service #{CF_APP} #{tester.service_instance}"
    run "cf start #{CF_APP}"

    # Wait for the app to be staged and started.
    app_guid = capture("cf app #{CF_APP} --guid")
    puts "# app GUID: #{app_guid}"
    STDOUT.flush
    loop do
        app_info = JSON.load capture("cf curl '/v2/apps/#{app_guid}'")
        puts "# app info: #{app_info}"
        STDOUT.flush
        break if app_info['entity']['state'] == 'STARTED'
        sleep 10
    end

    # Determine the endpoint the app will be listening on for requests.
    route_mappings = JSON.load capture("cf curl '/v2/apps/#{app_guid}/route_mappings'")
    run "echo '#{route_mappings.to_json}' | jq -C ."
    STDOUT.flush

    route_url = route_mappings['resources'].map{ |resource| resource['entity']['route_url'] }.reject(&:nil?).reject(&:empty?).first
    puts "# Route URL: #{route_url}"
    STDOUT.flush

    route_info = JSON.load capture("cf curl #{route_url}")
    run "echo '#{route_info.to_json}' | jq -C ."
    STDOUT.flush

    app_host = route_info['entity']['host']
    domain_url = route_info['entity']['domain_url']

    domain_info = JSON.load capture("cf curl #{domain_url}")
    run "echo '#{domain_info.to_json}' | jq -C ."
    STDOUT.flush

    app_domain = domain_info['entity']['name']
    app_url = "http://#{app_host}.#{app_domain}"

    # Check with the app at its endpoint that it is able to use the
    # service it was bound to.
    title = random_suffix('desired-title')
    body = random_suffix('desired-body')
    run "cf env #{CF_APP}"
    _ = run_with_status "curl -L -v --fail -X POST #{app_url}/post/new --data 'post[title]=#{title}' --data 'post[body]=#{body}'"
    run "curl -L #{app_url} | grep -F '#{title}'"
    run "curl -L #{app_url} | grep -F '#{body}'"
end
