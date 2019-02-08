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

# test ssh connection
run "cf ssh -i 0 #{app_name} -c /usr/bin/env | grep CF_INSTANCE_INDEX | cut -d'=' -f 2"
