#!/usr/bin/env ruby
require_relative 'testutils'

# Origin of the various pieces of configuration.
##
# APPS_DOMAIN   = <%= p('smoke_tests.apps_domain') %>

APPS_DOMAIN   = ENV['APPS_DOMAIN']
AUTOSCALER_URL   = ENV['AUTOSCALER_URL']
NAMESPACE     = ENV['KUBERNETES_NAMESPACE']

STATEFULSETS = [ 'autoscaler-api',
                 'autoscaler-actors',
                 'autoscaler-metrics',
                 'autoscaler-postgres']

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
policy       = '/var/vcap/packages/acceptance-tests-brain/test-resources/policy.json'
app_name     = random_suffix('dora')
broker_name  = random_suffix('SCALER')
service_name = random_suffix('SERVICE')
url          = "http://#{app_name}.#{APPS_DOMAIN}"

at_exit do
  puts "Exiting. Cleanup."
  STDOUT.flush
  set errexit: false do
    run "cf", "delete", "-f", app_name
    end
end

run "cf", "push", app_name, "--no-start", "-p", dora
run "cf", "push", app_name, "--no-start", "-p", dora
run "cf", "add-plugin-repo", "CF-Community", "https://plugins.cloudfoundry.org"
run "cf", "install-plugin", "-f", "-r", "CF-Community", "app-autoscaler-plugin"
run "ls","-l",policy
run "cf", "asa", AUTOSCALER_URL
run "cf", "aasp", app_name, policy

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
