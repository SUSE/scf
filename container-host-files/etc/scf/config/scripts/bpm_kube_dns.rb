#!/usr/bin/env ruby

# This script fixes the BPM configuration for all jobs to allow extra unsafe
# mounts to enable support for kube-dns and host SSL certificates.
# This script is expected to run after configgin has evaluated all the BOSH
# templates.  This will go away with the transition to the cf-operator, which
# will not require BPM anymore.


# Funny prefix to make this bash/ruby polyglot because run.sh runs all scripts
# under bash.
if [ 1 == 2 ] ; then
    # This is only run under ruby (because `if (Array)` is true)
=begin
fi
    # This section is bash-only
    set -o xtrace
    exec ruby -- "$0"
=end
end

require 'yaml'


# Notes on "unsafe.unrestricted_volumes":
#
# - The first three mounts are required to make DNS work in the nested
#   container created by BPM for the job to run in.
#
# - The remainder are required to give the job access to the system
#   root certificates so that it actually can verify the certs given
#   to it by its partners (like the router-registrar).
DESIRED_PATHS = %w(
    /etc/hostname
    /etc/hosts
    /etc/resolv.conf
    /etc/ssl
    /var/lib/ca-certificates
)

Dir.glob('/var/vcap/jobs/*/config/bpm.yml').each do |filename|
    sentinel = "#{filename}.bpm.sentinel"
    if File.exist? sentinel
        STDERR.puts "Skipping BPM patch for #{filename} -- sentinel exists"
        next
    end
    STDERR.puts "Fixing BPM volume configuration #{filename}"
    config = YAML.load_file(filename)
    config['processes'].each do |process|
        process['unsafe'] ||= {}
        process['unsafe']['unrestricted_volumes'] ||= []
        process['unsafe']['unrestricted_volumes'].tap do |volumes|
            DESIRED_PATHS.each do |path|
                next if volumes.any? { |v| v['path'] == path }
                volumes << { 'path' => path }
            end
        end
    end
    File.open(filename, 'w') { |f| YAML.dump(config, f) }
end
