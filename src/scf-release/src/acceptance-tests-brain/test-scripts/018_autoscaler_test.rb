#!/usr/bin/env ruby
require_relative 'testutils'

# Origin of the various pieces of configuration.
##
# APPS_DOMAIN   = <%= p('smoke_tests.apps_domain') %>
# BROKER_URL    = <%= p('smoke_tests.autoscaler_service_broker_endpoint') %>
# BROKER_USER   = <%= p('autoscaler.service_broker.username') %>
# BROKER_PASS   = <%= p('autoscaler.service_broker.password') %>
# SMOKE_SERVICE = <%= p('autoscaler.smoke.service_name') %>
# SMOKE_PLAN    = <%= p('autoscaler.smoke.service_plan') %>

APPS_DOMAIN   = ENV['APPS_DOMAIN']
BROKER_USER   = ENV['BROKER_USER']
BROKER_PASS   = ENV['BROKER_PASS']
BROKER_URL    = ENV['BROKER_URL']
SMOKE_SERVICE = ENV['SMOKE_SERVICE']
SMOKE_PLAN    = ENV['SMOKE_PLAN']
NAMESPACE     = ENV['KUBERNETES_NAMESPACE']

STATEFULSETS = [ 'autoscaler-api',
                 'autoscaler-eventgenerator',
                 'autoscaler-metrics',
                 'autoscaler-operator',
                 'autoscaler-postgres',
                 'autoscaler-scalingengine',
                 'autoscaler-scheduler',
                 'autoscaler-servicebroker' ]

# ~ ~~ ~~~ ~~~~~ ~~~~~~~~ ~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~~~~~~
## Check if autoscaler pods are running.

active_autoscaler_pods = 0
STATEFULSETS.each do |name|
  if statefulset_ready(NAMESPACE, name)
    active_autoscaler_pods += 1
  else
    puts "#{c_red}Reqired autoscaler pod #{c_bold}#{name}#{c_red} is not active.#{c_reset}"
  end
end

# Skip the test if none of the autoscaler pods are running.
puts "#{c_red}Autoscaler inactive.#{c_reset}" if active_autoscaler_pods == 0
exit_skipping_test if active_autoscaler_pods == 0

# Fail the test if some, but not all of the autoscaler pods are
# running.
fail "Have only #{active_autoscaler_pods} active autoscaler pods out of #{STATEFULSETS.length} required." \
  if active_autoscaler_pods < STATEFULSETS.length

puts "Autoscaler active. Testing begins."
STDOUT.flush

# ~ ~~ ~~~ ~~~~~ ~~~~~~~~ ~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~~~~~~
## Standard cf cli access.

login
setup_org_space

# ~ ~~ ~~~ ~~~~~ ~~~~~~~~ ~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~~~~~~
##

dora         = '/var/vcap/packages/acceptance-tests/src/github.com/cloudfoundry/cf-acceptance-tests/assets/dora'
app_name     = random_suffix('dora')
broker_name  = random_suffix('SCALER')
service_name = random_suffix('SERVICE')
url          = "http://#{app_name}.#{APPS_DOMAIN}"

at_exit do
  puts "Exiting. Cleanup."
  STDOUT.flush
  set errexit: false do
    run "cf", "unbind-service", app_name, service_name
    run "cf", "delete", "-f", app_name
    run "cf", "delete-service", service_name, "-f"
    run "cf", "delete-service-broker", broker_name, "-f"
    end
end

run "cf", "push", app_name, "--no-start", "-p", dora
run "cf", "create-service-broker", broker_name, BROKER_USER, BROKER_PASS, BROKER_URL
run "cf", "service-access"
run "cf", "enable-service-access", SMOKE_SERVICE, "-p", SMOKE_PLAN
run "cf", "create-service", SMOKE_SERVICE, SMOKE_PLAN, service_name

run "cf", "bind-service", app_name, service_name, "-c", "{
    \"instance_min_count\": 1,
    \"instance_max_count\": 4,
    \"scaling_rules\": [{
        \"metric_type\": \"memoryused\",
        \"stat_window_secs\": 60,
        \"breach_duration_secs\": 60,
        \"threshold\": 10,
        \"operator\": \">=\",
        \"cool_down_secs\": 300,
        \"adjustment\": \"+1\"
    }]
}"
run "cf", "start", app_name

puts "Waiting for the app to start..."
STDOUT.flush
run_with_retry 120, 1 do
  run "curl --silent '#{url}/' | grep Dora"
end
puts "\nApp started.\n"
STDOUT.flush

# ~ ~~ ~~~ ~~~~~ ~~~~~~~~ ~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~~~~~~

$app_uuid = capture "cf", "app", "--guid", app_name

# Determine the number of currently active app instances.
def get_count
  capture("cf curl /v2/apps/#{$app_uuid} | jq .entity.instances").to_i
end

puts "Checking that we initially have one instance...\n"
STDOUT.flush

run "cf", "app", app_name
count = get_count
fail "App has #{count} instances!\n" if count != 1

puts "Causing memory stress...\n"
STDOUT.flush
run "curl", "-X", "POST", "#{url}/stress_testers?vm=10&vm-bytes=100M"

puts "Waiting for new instances to start..."
STDOUT.flush
run_with_retry 24, 5 do
  run "cf", "app", app_name
  if get_count == 1
    # Force an error, i.e. a retry.
    raise RuntimeError, "no new instances"
  end
end

run "cf", "app", app_name

if get_count > 1
  puts "#{c_green}Instances increased.#{c_reset}"
else
  fail "Failed to increase instances."
end

# ~ ~~ ~~~ ~~~~~ ~~~~~~~~ ~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~~~~~~
