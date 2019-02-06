#!/usr/bin/env ruby

require_relative 'testutils'

login
setup_org_space

CF_TCP_DOMAIN = ENV.fetch('CF_TCP_DOMAIN', random_suffix('tcp') + ENV['CF_DOMAIN'])

app_name = random_suffix('tcp-route-node-env')
tempdir = mktmpdir
port = nil

at_exit do
    set errexit: false
    run "cf unmap-route #{app_name} #{CF_TCP_DOMAIN} --port #{port}" unless port.nil?
    run "cf delete-shared-domain -f #{CF_TCP_DOMAIN}"
    run "cf delete -f #{app_name}"
    set errexit: true
end

run "cf push #{app_name} -p #{resource_path('node-env')}"

# set up tcp routing
set errexit: false do
    run "cf delete-shared-domain -f #{CF_TCP_DOMAIN}"
end

run "cf create-shared-domain #{CF_TCP_DOMAIN} --router-group default-tcp"
run "cf update-quota default --reserved-route-ports -1"

run "cf map-route #{app_name} #{CF_TCP_DOMAIN} --random-port | tee #{tempdir}/log"

# retrieve the assigned random port
port = File.read("#{tempdir}/log").split(':')[1].split.first
if port.empty?
  STDERR.puts "ERROR: Could not determine the assigned random port number"
  STDERR.puts "ERROR: Mapping route to random port failed"
  exit 1
end

# Wait until the application itself is ready
run_with_retry 12, 5 do
    run "curl --fail -s -o /dev/null #{app_name}.#{ENV['CF_DOMAIN']}"
end

# check that the application works
sleep 5
run "curl #{CF_TCP_DOMAIN}:#{port}"
