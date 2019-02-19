#!/usr/bin/env ruby

# __Attention__
# This tests assumes that the kernel modules `nfs` and `nfsd` are
# already loaded.

require_relative 'testutils'
require 'json'
require 'yaml'

login
setup_org_space

NS = ENV['KUBERNETES_NAMESPACE']
SC = ENV['KUBERNETES_STORAGE_CLASS_PERSISTENT']

APP_NAME = random_suffix('pora')
SECGROUP = random_suffix('sg-nfs-test')
VOLUME_NAME = random_suffix('volume')

tmpdir = mktmpdir

at_exit do
    set errexit: false do
        # See why pora failed to start
        run "cf logs #{APP_NAME} --recent"

        # Delete the app, the associated service, block it from use again
        run "cf delete -f #{APP_NAME}"
        run "cf delete-route '#{ENV['DOMAIN']}' --hostname #{APP_NAME}"
        run "cf delete-service -f #{VOLUME_NAME}"
        run "cf disable-service-access persi-nfs"

        # Remove the test server
        run "kubectl delete -n #{NS} -f #{SKUBEC}"
    end
end

# Launch the NFS server to use by the service (See SMOUNT), and wait
# for it to be ready.

# Replace the placeholder storage class for persistent volumes with
# the actual class provided by the execution environment.
SKUBEC = "#{tmpdir}/nfs_server_kube.yaml"
run %Q@sed 's/storage-class: "persistent"/storage-class: "#{SC}"/' <#{resource_path('nfs_server_kube.yaml')} >#{SKUBEC}@

set errexit: false do
    run "kubectl delete -n #{NS} -f #{SKUBEC}"
end
run "kubectl create -n #{NS} -f #{SKUBEC}"
wait_for_namespace NS

# Server of the NFS volume to use, as name (pulled from the kube config)
SNAME = YAML.load_file(SKUBEC)['metadata']['name']

# Server of the NFS volume to use, as IP address (pulled from kube runtime via name)
capture("kubectl describe service -n #{NS} #{SNAME}").each_line do |line|
    next unless line.start_with? 'IP:'
    SADDR = line.split.last
    break
end

# Now that we have an NFS server, with an exportable volume, we can
# configure it for actual export.
##
# - Permissions for all
# - Declare as NFS export (insecure = allow any origin port)
# - Update the NFS master tables to include the new export

File.open("#{tmpdir}/export", 'w') { |f| f.puts '/exports/foo *(rw,insecure)' }
run "kubectl cp #{tmpdir}/export #{NS}/#{SNAME}-0:/etc/exports.d/foo.exports"

run "kubectl exec -n #{NS} #{SNAME}-0 -- chmod a+rwx /exports/foo"
run "kubectl exec -n #{NS} #{SNAME}-0 -- exportfs -a"

# Fix IP in the various configuration files
SGROUP = "#{tmpdir}/nfs_secgroup.json"
nfs_secgroups = File.open(resource_path('nfs_secgroup.json')) { |f| JSON.load(f) }
nfs_secgroups.map! { |sg| sg.tap { |sg| sg['destination'] = SADDR } }
File.open(SGROUP, 'w') { |f| f.puts nfs_secgroups.to_json }

SMOUNT = "#{tmpdir}/nfs_mount.json"
File.open(SMOUNT, 'w') { |f| f.puts({share: "#{SADDR}/exports/foo"}.to_json) }

# Show the security group, for debugging.
run "echo ======================== ; cat #{SGROUP} ; echo ========================"
run "echo ======================== ; cat #{SMOUNT} ; echo ========================"

# Create a security group which allows access to the nfs server
# Deploy the pora app of the pats, and bind it to a persi service

at_exit do
    set errexit: false do
        run "cf unbind-staging-security-group #{SECGROUP}"
        run "cf unbind-running-security-group #{SECGROUP}"
        run "cf delete-security-group -f #{SECGROUP}"
    end
end
run "cf create-security-group       #{SECGROUP} #{SGROUP}"
run "cf bind-running-security-group #{SECGROUP}"
run "cf bind-staging-security-group #{SECGROUP}"

run "cf push #{APP_NAME} --no-start", chdir: resource_path('persi-acceptance-tests/assets/pora')

run "cf enable-service-access persi-nfs"
run "cf create-service        persi-nfs Existing #{VOLUME_NAME} -c $(cat #{SMOUNT})"

run %Q@cf bind-service #{APP_NAME} #{VOLUME_NAME} -c '{"uid":"1000","gid":"1000"}'@
run "cf start #{APP_NAME}"

APP_URL = "#{APP_NAME}.#{ENV['CF_DOMAIN']}"
PATTERN = 'Hello Persistent World!'

# Test that the app is available
run "curl #{APP_URL}"

# Test that the app can write to the volume of the bound service
run "curl #{APP_URL}/write | grep '#{PATTERN}'"

# Test that we can create, read, chmod, and delete a file.  We check
# the curl results in part, and, more importantly the pod holding the
# actual volume in part.

FNAME = capture("curl #{APP_URL}/create")

run "kubectl exec -n #{NS} #{SNAME}-0 -- ls /exports/foo | grep #{FNAME}"
run "kubectl exec -n #{NS} #{SNAME}-0 -- grep '#{PATTERN}' /exports/foo/#{FNAME}"

run "curl #{APP_URL}/read/#{FNAME} | grep '#{PATTERN}'"

run "curl #{APP_URL}/chmod/#{FNAME}/755"
run "kubectl exec -n #{NS} #{SNAME}-0 -- ls -l /exports/foo/#{FNAME} | grep '^-rwxr-xr-x '"

run "curl #{APP_URL}/delete/#{FNAME}"
