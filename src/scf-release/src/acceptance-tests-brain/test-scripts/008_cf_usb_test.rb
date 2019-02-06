#!/usr/bin/env ruby

## Explanations and overview:

## This test does a lot of setup to determine that the universal
## service broker (cf-usb) is actually working.
#
## 0. A domain for TCP routing is created, to connect all the pieces.
#
## 1. A local mysql server is started as an app and made available
##    through cf TCP routing.
#
## 2. The mysql sidecar is started as an app, configured to talk to
##    the mysql server from (1).
#
## 3. The cf-usb is configured to talk to and use the side car.
#
## 4. Then we can check that mysql appears in the marketplace, create
##    a service from it, and check that this service is viewable too.
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

login
setup_org_space
$tmpdir = mktmpdir

def get_port(app_name, domain_name)
    run "cf curl /v2/apps/$(cf app #{app_name} --guid)/routes?inline-relations-depth=1 > #{$tmpdir}/routes.json"
    routes = File.open("#{$tmpdir}/routes.json") { |f| JSON.load(f) }
    routes['resources'].each do |resource|
        next unless resource['metadata']['url'].start_with? '/v2/routes/'
        next unless resource['entity']['domain']['entity']['name'] == domain_name
        return resource['entity']['port']
    end
    fail "Failed for find TCP port for #{app_name} in domain #{domain_name}"
end

def wait_on_database(port, user, password)
    run_with_retry 60, 5 do
        run "mysql -u#{user} -p#{password} -P #{port} -h #{CF_TCP_DOMAIN} > /dev/null"
    end
    # Last try, any error will abort the test
    run "mysql -u#{user} -p#{password} -P #{port} -h #{CF_TCP_DOMAIN}"
end

CF_TCP_DOMAIN = ENV.fetch('CF_TCP_DOMAIN', random_suffix('tcp') + ENV['CF_DOMAIN'])

MYSQL_USER = 'root'
MYSQL_PASS = 'testpass'

SERVER_APP = random_suffix('mysql')

SIDECAR_API_KEY = random_suffix('secret-key')
SIDECAR_APP = random_suffix('msc')

SERVICE_TYPE = random_suffix('my-service')
SERVICE_INSTANCE = random_suffix('my-db')

SECGROUP_NAME = random_suffix('secgroup')


## # # ## ### Test-specific code ### ## # #

at_exit do
    set errexit: false do
        # Reverse order of creation ...
        # - service instance
        # - service type = usb endpoint
        # - msc sidecar app
        # - mysql server app
        # - security groups
        # - tcp routing
        # - temp directory

        run "cf delete-service -f #{SERVICE_INSTANCE}"
        run "yes | cf usb-delete-driver-endpoint #{SERVICE_TYPE}"
        run "cf delete -f #{SIDECAR_APP}"
        run "cf delete -f #{SERVER_APP}"
        run "cf unbind-running-security-group #{SECGROUP_NAME}"
        run "cf unbind-staging-security-group #{SECGROUP_NAME}"
        run "cf delete-shared-domain -f #{CF_TCP_DOMAIN}"
    end
end

# --(0)-- Initialize tcp routing

set errexit: false do
    run "cf delete-shared-domain -f #{CF_TCP_DOMAIN}"
end
run "cf create-shared-domain #{CF_TCP_DOMAIN} --router-group default-tcp"
run "cf update-quota default --reserved-route-ports -1"

# --(0.1) -- Initialize a security group to allow for inter-app comms
# Attention: This SG opens the entire internal kube service network.

File.open("#{$tmpdir}/internal-services.json", 'w') do |f|
    f.puts [ { destination: '0.0.0.0/0', protocol: 'all' } ].to_json
end

run "cf create-security-group       #{SECGROUP_NAME} #{$tmpdir}/internal-services.json"
run "cf bind-running-security-group #{SECGROUP_NAME}"
run "cf bind-staging-security-group #{SECGROUP_NAME}"

## --(1)-- Create and configure the mysql server

# Use MySQL 8.0.3, as MySQL defaults to the sha2 authentication plugin in 8.0.4
# which isn't supported by github.com/go-sql-driver/mysql (the MySQL driver in
# use in the USB broker).
# https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_default_authentication_plugin
# https://github.com/go-sql-driver/mysql/issues/785
run "cf push --no-start --no-route --health-check-type none #{SERVER_APP} -o mysql/mysql-server:8.0.3"
run "cf map-route #{SERVER_APP} #{CF_TCP_DOMAIN} --random-port"
run "cf set-env   #{SERVER_APP} MYSQL_ROOT_PASSWORD #{MYSQL_PASS}"
run "cf set-env   #{SERVER_APP} MYSQL_ROOT_HOST '%'"
run "cf start     #{SERVER_APP}"

MYSQL_PORT = get_port(SERVER_APP, CF_TCP_DOMAIN)
wait_on_database MYSQL_PORT, MYSQL_USER, MYSQL_PASS

## --(2)-- Create and configure the mysql client sidecar for usb.

run "cf push #{SIDECAR_APP} --no-start -o registry.suse.com/cap/cf-usb-sidecar-mysql:1.0.1"

# Use a secret key that will be used by the USB to talk to your
# sidecar, and set the connection parameters for the mysql client
# sidecar so that it can talk to the mysql server from the previous
# step.
run "cf set-env #{SIDECAR_APP} SIDECAR_API_KEY    #{SIDECAR_API_KEY}"
run "cf set-env #{SIDECAR_APP} SERVICE_MYSQL_HOST #{CF_TCP_DOMAIN}"
run "cf set-env #{SIDECAR_APP} SERVICE_MYSQL_PORT #{MYSQL_PORT}"
run "cf set-env #{SIDECAR_APP} SERVICE_MYSQL_USER #{MYSQL_USER}"
run "cf set-env #{SIDECAR_APP} SERVICE_MYSQL_PASS #{MYSQL_PASS}"
run "cf start   #{SIDECAR_APP}"

# --(3)-- Create a driver endpoint to the mysql sidecar (== service type)
# Note that the -c ":" is required as a workaround to a known issue
run 'cf', 'usb-create-driver-endpoint', SERVICE_TYPE,
    "https://#{SIDECAR_APP}.#{ENV['CF_DOMAIN']}",
    SIDECAR_API_KEY,
    '-c', ':'

# --(4)-- Check that the service is available in the marketplace and use it

## Note: The commands without grep filtering are useful in case of
## failures, providing immediate information about the data which runs
## through and fails the filter.

run "cf marketplace"
run "cf marketplace | grep #{SERVICE_TYPE}"

run "cf create-service #{SERVICE_TYPE} default #{SERVICE_INSTANCE}"

run "cf services"
run "cf services | grep #{SERVICE_INSTANCE}"

# -- If we want to, we can now create and push an app which uses the
#    service-instance as database, and verify that it works.

exit 0
