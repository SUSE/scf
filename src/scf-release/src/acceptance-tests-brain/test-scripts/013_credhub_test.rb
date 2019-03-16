#!/usr/bin/env ruby

require_relative 'testutils'
require 'base64'
require 'json'

NAMESPACE = ENV['KUBERNETES_NAMESPACE']
STATEFULSET_NAME = 'credhub-user'

# Check if credhub is running, otherwise skip the test.
exit_skipping_test if !statefulset_ready(NAMESPACE, STATEFULSET_NAME)

login
setup_org_space

CH_CLI = 'credhub'
CH_SERVICE = "https://credhub.#{ENV['CF_DOMAIN']}"

# Ask a pod for the name of the relevant secret. This handles HA
# properly, and query after a rotation as well.

# Regarding the use of `nats` below:
# - Wanted a central pod/job which when missing indicates/causes much
#   bigger trouble than failing brain tests. I.e. if that is missing
#   we should never reach the tests. Of course, there are more than
#   just `nats` which would do. It was just the one which popped into
#   my mind.

nats_info = JSON.load capture("kubectl get pods --namespace #{NAMESPACE} --selector app.kubernetes.io/component=nats -o json")
SECRET = nats_info['items'].map do |item|
    item['spec']['containers'].
        find { |c| c['name'] == 'nats' }['env'].
        find { |e| e['name'] == 'INTERNAL_CA_CERT' }['valueFrom']['secretKeyRef']['name']
end.first

secrets = JSON.load capture("kubectl get secrets --namespace #{NAMESPACE} #{SECRET} -o json")
CH_SECRET = Base64.decode64(secrets['data']['uaa-clients-credhub-user-cli-secret'])
CH_CLIENT = 'credhub_user_cli'

tmpdir = mktmpdir

# Target the credhub kube service, via the registered gorouter endpoint
run "#{CH_CLI} api --skip-tls-validation --server #{CH_SERVICE}"

# Log into credhub
run "#{CH_CLI} login --client-name=#{CH_CLIENT} --client-secret=#{CH_SECRET}"

# Insert ...
run "#{CH_CLI} set -n FOX -t value -v 'fox over lazy dog' > #{tmpdir}/fox"
run "#{CH_CLI} set -n DOG -t user -z dog -w fox           > #{tmpdir}/dog"

# Retrieve ...
run "#{CH_CLI} get -n FOX > #{tmpdir}/fox2"
run "#{CH_CLI} get -n DOG > #{tmpdir}/dog2"

# Show (in case of failure) ...
%w(fox fox2 dog dog2).each do |filename|
    puts "__________________________________ #{filename}"
    run "cat #{tmpdir}/#{filename}"
end
puts "__________________________________"

# Check ...

run "grep 'name: /FOX'        #{tmpdir}/fox"
run "grep 'type: value'       #{tmpdir}/fox"
run "grep 'value: <redacted>' #{tmpdir}/fox"

run "grep 'name: /FOX'               #{tmpdir}/fox2"
run "grep 'type: value'              #{tmpdir}/fox2"
run "grep 'value: fox over lazy dog' #{tmpdir}/fox2"

id = File.open("#{tmpdir}/fox") do |f|
    f.each_line.find{ |line| line.start_with? 'id:' }.split[1]
end
run "grep '^id: #{id}$' #{tmpdir}/fox2"

run "grep 'name: /DOG'        #{tmpdir}/dog"
run "grep 'type: user'        #{tmpdir}/dog"
run "grep 'value: <redacted>' #{tmpdir}/dog"

run "grep 'name: /DOG'        #{tmpdir}/dog2"
run "grep 'type: user'        #{tmpdir}/dog2"

id = File.open("#{tmpdir}/dog") do |f|
    f.each_line.find{ |line| line.start_with? 'id:' }.split[1]
end
run "grep '^id: #{id}$' #{tmpdir}/dog2"

run "grep 'password: fox' #{tmpdir}/dog2"
run "grep 'username: dog' #{tmpdir}/dog2"

# Not checking the `password_hash` (it is expected to change from run
# to run, due to random seed changes, salting)
#
# Similarly, `version_created_at` is an ever changing timestamp.
