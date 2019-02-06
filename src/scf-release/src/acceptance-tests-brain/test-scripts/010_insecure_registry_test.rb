#!/usr/bin/env ruby

require_relative 'testutils'
require 'fileutils'
require 'json'

login
setup_org_space

CF_TCP_DOMAIN = ENV.fetch('CF_TCP_DOMAIN', random_suffix('tcp') + ENV['CF_DOMAIN'])
CF_SEC_GROUP = random_suffix('sg', 'CF_SEC_GROUP')

at_exit do
    set errexit: false do
        run "cf delete-security-group -f #{CF_SEC_GROUP}"
    end
end

tmpdir = mktmpdir

File.open("#{tmpdir}/secgroup.json", 'w') do |f|
    f.puts [ { destination: '0.0.0.0/0', protocol: 'all' } ].to_json
end
run "cf create-security-group #{CF_SEC_GROUP} #{tmpdir}/secgroup.json"
run "cf bind-security-group #{CF_SEC_GROUP} #{$CF_ORG} #{$CF_SPACE} --lifecycle staging"
run "cf bind-security-group #{CF_SEC_GROUP} #{$CF_ORG} #{$CF_SPACE} --lifecycle running"

REGISTRIES = {
    'secure-registry'   => "https://secure-registry.#{ENV['CF_DOMAIN']}",          # Router SSL cert
    'insecure-registry' => "https://insecure-registry.#{ENV['CF_DOMAIN']}:20005",  # Self-signed SSL cert
}

at_exit do
    set errexit: false do
        REGISTRIES.each_key do |registry|
            run "cf delete -f #{registry}"
        end
        run "cf delete-route -f #{ENV['CF_DOMAIN']} --hostname secure-registry"
        run "cf delete-route -f #{CF_TCP_DOMAIN} --port 20005"
        run "cf delete-shared-domain -f #{CF_TCP_DOMAIN}"
    end
end

# set up tcp routing for the invalid-cert registry
set errexit: false do
    run "cf delete-shared-domain -f #{CF_TCP_DOMAIN}"
end

run "cf create-shared-domain #{CF_TCP_DOMAIN} --router-group default-tcp"
run "cf update-quota default --reserved-route-ports -1"

# Deploy the registry
FileUtils::Verbose.cp resource_path('docker-uploader/manifest.yml'),
    '/var/vcap/packages/docker-distribution/manifest.yml'
FileUtils::Verbose.cp resource_path('docker-uploader/config.yml'),
    '/var/vcap/packages/docker-distribution/config.yml'
FileUtils::Verbose.cp '/var/vcap/packages/acceptance-tests-brain/bin/docker-uploader',
    '/var/vcap/packages/docker-distribution/bin/'
FileUtils::Verbose.cp '/var/vcap/packages/acceptance-tests-brain/bin/registry',
    '/var/vcap/packages/docker-distribution/bin/'
at_exit do
    set errxit: false do
        run "cf delete -f secure-registry"
        run "cf delete -f insecure-registry"
        run "cf delete -f uploader"
    end
end
run "cf push -f manifest.yml --var domain=#{ENV['CF_DOMAIN']} --var tcp-domain=#{CF_TCP_DOMAIN}",
    chdir: '/var/vcap/packages/docker-distribution/'

run 'cf apps'

REGISTRIES.each_pair do |regname, registry_url|
    # Wait for the registry to be available
    run_with_retry 60, 1 do
        run "curl -kv #{registry_url}/v2/"
    end
    begin
        run "curl --fail http://uploader.#{ENV['CF_DOMAIN']} -d registry=#{registry_url} -d name=image"
    rescue
        set errexit: false do
            run "cf logs uploader --recent"
            run "cf logs #{regname} --recent"
        end
        raise
    end
end

caught_error = nil

REGISTRIES.each_pair do |regname, registry_url|
    begin
        registry = registry_url.sub %r#^https://#, ''
        run "cf push from-#{regname} --docker-image #{registry}/image:latest"
    rescue RuntimeError => e
        caught_error = e
        set errexit: false do
            run "cf logs --recent from-#{regname}"
            run "cf logs --recent #{regname}"
        end
    ensure
        set errexit: false do
            run "cf delete -f from-#{regname}"
        end
    end
end
raise caught_error if caught_error
