#!/var/vcap/packages/ruby-2.3/bin/ruby

# This script gets the users from the cloud-controller and deletes any
# that look bogus:
# metadata: guid doesn't match a GUID
# AND
# No entity:username assigned
#
# Usage: $0 <CF-API endpoint> [--insecure]

require 'json'
require 'open3'

CF_CONFIG_PATH = File.expand_path('~/.cf/config.json')

api_endpoint, skip_ssl = ARGV.take(2)

if [api_endpoint].any? { |x| x.nil? || x.empty? }
  raise 'Invalid arguments; usage: $0 <CF endpoint> [--insecure]'
end

def capture2(*args)
  args.reject!(&:empty?)
  output, status = Open3.capture2(*args)
  raise "Failed running `#{args}` with #{status.exitstatus}" unless status.success?
  output
end

cf_config = open(CF_CONFIG_PATH, 'r') { |f| JSON.load(f) }
puts "Getting users from #{api_endpoint}..."

users = JSON.load(capture2('curl', '--fail', skip_ssl.to_s,
                           '--header', 'Accept: application/json',
                           '--header', "Authorization: #{cf_config['AccessToken']}",
                           "#{api_endpoint}/v2/users"))['resources']
guid_p = /\A[-a-zA-Z0-9]{36}\z/
puts "Read #{users.size} user entries"
users.each do |user|
  puts user['metadata']
  puts user['metadata']['guid']
  guid = user['metadata']['guid']
  next if guid_p.match(guid) || user['entity'].key?('username')
  $stderr.puts("Eliminating user #{guid}")
  res = capture2('curl', '--silent', '--fail', skip_ssl.to_s,
                 '--header', 'Accept: application/json',
                 '--header', 'Content-type: application/x-www-form-urlencoded',
                 '--header', "Authorization: #{cf_config['AccessToken']}",
                 '-X', 'DELETE',
                 "#{api_endpoint}/v2/users/#{guid}")
  $stderr.puts("Attempt to delete user #{guid}: #{res}")
end
