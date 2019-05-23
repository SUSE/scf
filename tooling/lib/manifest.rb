require 'open-uri'
require 'yaml'

class Manifest
    def initialize
    end

    def self.load_from_upstream(version:)
        version = "v#{version}" unless version.start_with? 'v'

        upstream_manifest = open("https://github.com/cloudfoundry/cf-deployment/raw/#{version}/cf-deployment.yml") do |f|
            YAML.load(f)
        end
        fail "Error loading upstream manifest" unless upstream_manifest['releases']
        upstream_manifest
    end
end
