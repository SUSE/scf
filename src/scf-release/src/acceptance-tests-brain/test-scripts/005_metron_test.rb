#!/usr/bin/env ruby

require_relative 'testutils'

login
setup_org_space

app_name = random_suffix('node-env')

at_exit do
    set errexit: false do
        run "cf delete -f #{app_name}"
    end
end
run "cf push #{app_name} -p #{resource_path('node-env')}"

# test if there are logs
run "cf logs #{app_name} --recent | grep -i Downloading"
