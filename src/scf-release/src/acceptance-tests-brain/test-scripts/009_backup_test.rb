#!/usr/bin/env ruby

require_relative 'testutils'
require 'json'

login
setup_org_space

APP_NAME = random_suffix('node-env')
ORG_ROLES = {OrgManager: 'managers', BillingManager: 'billing_managers', OrgAuditor: 'auditors'}
SPACE_ROLES = {SpaceManager: 'managers', SpaceDeveloper: 'developers', SpaceAuditor: 'auditors'}
tmpdir = mktmpdir

at_exit do
    set errexit: false do
        run "cf delete -f #{APP_NAME}"
        ORG_ROLES.each_key do |role|
            run "cf delete-user -f #{$CF_ORG}-#{role}"
        end
        SPACE_ROLES.each_key do |role|
            run "cf delete-user -f #{$CF_SPACE}-#{role}"
        end
    end
end

ORG_ROLES.each_key do |role|
    run "cf create-user #{$CF_ORG}-#{role} hunter2"
    run "cf set-org-role #{$CF_ORG}-#{role} #{$CF_ORG} #{role}"
end
SPACE_ROLES.each_key do |role|
    run "cf create-user #{$CF_SPACE}-#{role} hunter2"
    run "cf set-space-role #{$CF_SPACE}-#{role} #{$CF_ORG} #{$CF_SPACE} #{role}"
end

# Push an app to save.
run "cf push #{APP_NAME} -p #{resource_path 'node-env'}"

# Check that the app is up.
run "curl --head #{APP_NAME}.#{ENV['CF_DOMAIN']}"
run "curl --head #{APP_NAME}.#{ENV['CF_DOMAIN']} | head -n1 | grep -w 200"

# Backup everything.
run "cf backup snapshot"

# Remove everything so we can test the restoration.
ORG_ROLES.each_key do |role|
    run "cf unset-org-role #{$CF_ORG}-#{role} #{$CF_ORG} #{role}"
end
SPACE_ROLES.each_key do |role|
    run "cf unset-space-role #{$CF_SPACE}-#{role} #{$CF_ORG} #{$CF_SPACE} #{role}"
end
run "cf delete -f #{APP_NAME}"
run "cf delete-space -f #{$CF_SPACE}"
run "cf delete-org -f #{$CF_ORG}"

# Check that the org is gone.
begin
    run "cf target -o #{$CF_ORG}"
    fail "Successfully targeted org #{$CF_ORG} after deleting it"
rescue RuntimeError => e
    raise e unless e.message.include? "exited with"
end

run "cf backup restore"

run "cf target -o #{$CF_ORG} -s #{$CF_SPACE}"

# Check that the roles are restored.
run "cf org-users #{$CF_ORG}"
ORG_ROLES.each_pair do |name, api|
    run "cf curl /v2/organizations/$(cf org #{$CF_ORG} --guid)/#{api}?inline-relations-depth=1 > #{tmpdir}/users.json"
    users = File.open("#{tmpdir}/users.json") { |f| JSON.load(f) }
    wanted_user = users['resources'].find do |resource|
        resource['entity']['username'] == "#{$CF_ORG}-#{name}"
    end
    fail "Could not find user #{$CF_ORG}-#{name}" unless wanted_user
end

SPACE_ROLES.each_pair do |name, api|
    run "cf curl /v2/spaces/$(cf space #{$CF_SPACE} --guid)/#{api}?inline-relations-depth=1 > #{tmpdir}/users.json"
    users = File.open("#{tmpdir}/users.json") { |f| JSON.load(f) }
    wanted_user = users['resources'].find do |resource|
        resource['entity']['username'] == "#{$CF_SPACE}-#{name}"
    end
    fail "Could not find user #{$CF_SPACE}-#{name}" unless wanted_user
end

# Check if the app exists again.
run "cf apps | grep #{APP_NAME}"

run_with_retry 30, 10 do
    run "cf app #{APP_NAME} | grep -E '^#.*running'"
end

# Check that the app is routable.
run "curl --head #{APP_NAME}.#{ENV['CF_DOMAIN']}"
run "curl --head #{APP_NAME}.#{ENV['CF_DOMAIN']} | head -n1 | grep -w 200"
