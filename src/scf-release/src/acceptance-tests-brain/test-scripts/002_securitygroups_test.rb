#!/usr/bin/env ruby

require_relative 'testutils'

login
setup_org_space

secgroup_name = random_suffix('secgroup')

at_exit do
    set errexit: false do
        # unbind security groups from containers that stage and run apps
        run "cf unbind-staging-security-group #{secgroup_name}"
        run "cf unbind-running-security-group #{secgroup_name}"

        run "cf delete-security-group -f #{secgroup_name}"
    end
end

run "cf create-security-group #{secgroup_name} #{resource_path('secgroup.json')}"

# bind new security group to containers that run and stage apps
run "cf bind-running-security-group #{secgroup_name}"
run "cf bind-staging-security-group #{secgroup_name}"
