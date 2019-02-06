#!/usr/bin/env ruby

require_relative 'testutils'

require 'json'

login
setup_org_space

tmpdir = mktmpdir

at_exit do
    set errexit: false do
        run "cf delete-buildpack -f buildpack_inspector_buildpack"
    end
end

# Sample output:
##
# Getting buildpacks...
#
# buildpack              position   enabled   locked   filename
# staticfile_buildpack   1          true      false    staticfile_buildpack-v1.3.13.zip
# java_buildpack         2          true      false    java-buildpack-v3.10.zip
# ruby_buildpack         3          true      false    ruby_buildpack-v1.6.28.zip
# nodejs_buildpack       4          true      false    nodejs_buildpack-v1.5.23.zip
# go_buildpack           5          true      false
# python_buildpack       6          true      false
# php_buildpack          7          true      false    php_buildpack-v4.3.22.zip
# binary_buildpack       8          true      false    binary_buildpack-v1.0.5.zip
##
# 123456789.123456789.12 123456789. 123456789 12345678 123456789.123456789.123456789.123456789.1

run "cf buildpacks" # Show in the logs, for troubleshooting
run "cf curl /v2/buildpacks > #{tmpdir}/buildpacks"
raw_buildpacks = File.open("#{tmpdir}/buildpacks") { |f| JSON.load(f) }
buildpacks = raw_buildpacks['resources'].map { |resource| resource['entity'] }
buildpacks.sort_by! { |buildpack| buildpack['position'].to_i }

STANDARD_BUILDPACKS = %w(
    binary
    dotnet-core
    go
    java
    nodejs
    php
    python
    ruby
    staticfile
)

# Check that the (nine) standard buildpacks are present
STANDARD_BUILDPACKS.each do |shortname|
    buildpack = buildpacks.find do |buildpack|
        buildpack['name'] == "#{shortname}_buildpack"
    end
    fail "Did not find standard buildpack #{shortname}_buildpack" unless buildpack
end

# Check that all buildpacks have a name and a filename
buildpacks.each do |buildpack|
    puts "Got name #{buildpack['name']} for position #{buildpack['position']}"
    fail "Buildpack has no name" if buildpack['name'].nil? || buildpack['name'].empty?

    # Note: A missing file indicates that the upload of the buildpack
    # archive failed in some way. Look in the cloud_controller_ng.log
    # for anomalies. The anomalies which triggered the writing of this
    # test were Mysql errors (transient loss of connection) which
    # prevented the registration of the uploaded archive in the CC-DB.

    puts "Got filename #{buildpack['filename']} for position #{buildpack['position']}"
    fail "Buildpack #{buildpack['name']} has no file name" if buildpack['filename'].nil? || buildpack['filename'].empty?
end

# Check that all buildpacks are uncached variants.
# In order to do so a special inspector buildpack is added which inspects all
# other buildpacks at staging time for cached dependencies.
# An empty app is then pushed which won't be accepted by any of the regular
# buildpacks. Only the inspector buildpack will accept the app if the "uncached"
# check passes.

# Add buildpack
inspector_filename = "#{tmpdir}/buildpack_inspector_buildpack_v0.0.1.zip"
run "zip -r #{inspector_filename} *", chdir: resource_path('buildpack_inspector_buildpack')
run "cf create-buildpack buildpack_inspector_buildpack #{inspector_filename} 1"

# Deploy app
dummy_app_dir = "#{tmpdir}/dummy-app"
Dir.mkdir dummy_app_dir
File.open("#{dummy_app_dir}/foo", 'w') { |f| } # touch
run "cf push dummy-app -c /bin/bash -u none -p #{dummy_app_dir}"
