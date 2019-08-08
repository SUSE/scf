#!/var/vcap/packages/ruby-2.5.5-r0.15.0/bin/ruby

# This file will get a client credential from UAA, and set the CF CLI's config
# to use that credential (which is normally impossible; the CF client is
# designed to be used via an OAuth user).
#
# Usage: $0 <UAA endpoint> <client id>:<client secret> [--insecure]
#
# NOTE: remove_temporary_users.rb must be called after the client credentials
# are not longer needed to prevent the client id from appearing in the CC's
# user list.

require 'json'
require 'open3'

CF_CONFIG_PATH = File.expand_path('~/.cf/config.json')

uaa_endpoint, $client_auth, skip_ssl = ARGV.take(3)

if [uaa_endpoint, $client_auth].any? { |x| x.nil? || x.empty? }
  fail "Invalid arguments; usage: $0 <UAA endpoint> <client id>:<client secret> [--insecure]"
end

def capture2(*args)
  args.reject!(&:empty?)
  output, status = Open3.capture2(*args)
  args.map { |x| x == $client_auth ? '<redacted>' : x }
  fail "Failed running `#{args}` with #{status.exitstatus}" unless status.success?
  output
end

puts "Logging in to #{uaa_endpoint}..."
uaa_auth = capture2(*%W(curl --fail #{skip_ssl} --header),
                    'Accept: application/json',
                    "#{uaa_endpoint}/oauth/token",
                    *%w(-d grant_type=client_credentials --user),
                    $client_auth)

uaa_token = JSON.load(uaa_auth)['access_token']

cf_config = open(CF_CONFIG_PATH, 'r') { |f| JSON.load(f) }
cf_config['AccessToken'] = "bearer #{uaa_token}"
cf_config['RefreshToken'] = ''
open(CF_CONFIG_PATH, 'w') { |f| JSON.dump(cf_config, f) }
