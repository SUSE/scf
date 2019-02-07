#!/usr/bin/env ruby

require_relative 'testutils'

login
setup_org_space

docker_app = random_suffix('docker-test-app')
at_exit do
    set errexit: false do
        run "cf delete -f #{docker_app}"
    end
end

# Test pushing a docker app
run "cf enable-feature-flag diego_docker"
registry = ''
registry = ENV['TESTBRAIN_DOCKER_REGISTRY'].chomp('/') + '/' if ENV.has_key? 'TESTBRAIN_DOCKER_REGISTRY'
run "cf push #{docker_app} -o \"#{registry}viovanov/node-env-tiny\""
