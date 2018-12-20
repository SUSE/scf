require 'yaml'

class ReleasesDiff
    # Path to the manifest relative to the root of the source tree
    attr_accessor :manifest_path
    # Absolute path to the old manifest
    attr_accessor :old_manifest
    # Absolute path to the current manifest
    attr_accessor :current_manifest

    def initialize(manifest_path = nil, output = nil)
        # Path where the manifest lives (inside the source tree)
        @manifest_path = manifest_path ? manifest_path : "container-host-files/etc/scf/config/role-manifest.yml"
        # The temp work dir used to download older releases
        @temp_work_dir='/tmp/scf-releases-diff'
        # Path where we save the old manifest
        @old_manifest="#{@temp_work_dir}/manifest.yaml"
        # Path to the current manifest
        @current_manifest=File.join(ReleasesDiff.git_root, @manifest_path)
        # A path to an empty properties file, to be used as opinions
        @empty_opinions_path=File.join(ReleasesDiff.git_root, 'tooling', 'empty_opinions.yaml')
        # Where output will be printed
        $stdout.sync = true
        @output=output ? output : $stdout
    end

    # Calculates the root of the source tree
    def self.git_root()
        `git rev-parse --show-toplevel`.strip()
    end

    # Gets the directory that contains all the final releases downloaded for SCF
    def current_final_releases_work_dir()
        current_manifest_path = File.join(ReleasesDiff.git_root, @manifest_path)
        File.join(File.expand_path('../', current_manifest_path), '.final_releases')
    end

    # Load the old manifest into an object
    def load_old_manifest()
        # Load the manifest from HEAD
        old_manifest = YAML.load(`git show HEAD:#{@manifest_path}`)
        return old_manifest
    end

    # Loads the current manifest into an object
    def load_current_manifest()
        current_manifest = YAML.load_file(@current_manifest)
        return current_manifest
    end

    # Saves the manifest from HEAD to a temporary directory
    def save_old_manifest()
        old_manifest = load_old_manifest()
        # We only want the releases block, and the releases that are
        # also used in our manifest
        minimal_manifest = {}
        minimal_manifest["releases"] = old_manifest["releases"]

        # Save the manifest in a temporary work directory
        `mkdir -p #{@temp_work_dir}`
        File.open(@old_manifest, 'w') {|f| f.write minimal_manifest.to_yaml }
    end

    # Runs fissile validate for the old manifest
    def fissile_validate_old_releases()
        system("env -u FISSILE_LIGHT_OPINIONS -u FISSILE_DARK_OPINIONS -u FISSILE_RELEASE -u FISSILE_ROLE_MANIFEST fissile validate --light-opinions #{@empty_opinions_path} --dark-opinions #{@empty_opinions_path} --role-manifest #{@old_manifest}", out: @output, err: @output)
    end

    # Runs fissile validate
    def fissile_validate_current_releases()
        system("env -u FISSILE_LIGHT_OPINIONS -u FISSILE_DARK_OPINIONS -u FISSILE_ROLE_MANIFEST fissile validate --light-opinions #{@empty_opinions_path} --dark-opinions #{@empty_opinions_path} --role-manifest #{@current_manifest}", out: @output, err: @output)
    end

    # Converts releases information into a map that only contains the information 
    # we need for calculating differences
    def get_releases_info(manifest, final_releases_dir)
        result = {}
        manifest['releases'].each do |release|
            result[release['name']] = {
                :path => File.join(final_releases_dir, "#{release['name']}-#{release['version']}-#{release['sha1']}"),
                :version => release['version']
            }
        end

        return result
    end

    # Gets current releases in a hash
    def get_current_releases()
        get_releases_info(load_current_manifest(), current_final_releases_work_dir())
    end

    # Gets old releases in a hash release name > release path
    def get_old_releases()
        get_releases_info(load_old_manifest(), File.join(@temp_work_dir, '.final_releases'))
    end

    # Prints added releases on stdout
    def print_added_releases()
        old_releases = get_old_releases()
        current_releases = get_current_releases()

        @output.puts "Added releases:"

        current_releases.each do |release_name, release|
            next if old_releases.key?(release_name)
            @output.puts "  #{release_name} (#{release[:version]})"
        end
    end

    # Prints removed releases on stdout
    def print_removed_releases()
        old_releases = get_old_releases()
        current_releases = get_current_releases()

        @output.puts "Removed releases:"

        old_releases.each do |release_name, release|
            next if current_releases.key?(release_name)
            @output.puts "  #{release_name} (#{release[:version]})"
        end
    end

    # Prints releases whose version hasn't changed
    def print_unchanged_releases()
        old_releases = get_old_releases()
        current_releases = get_current_releases()

        @output.puts "Unchanged releases:"

        old_releases.each do |release_name, release|
            next unless current_releases.key?(release_name)
            @output.puts "  #{release_name} (#{release[:version]})" if release[:version] == current_releases[release_name][:version]            
        end  
    end

    # Prints changed releases on stdout and details into a report file
    def print_changed_releases()
        old_releases = get_old_releases()
        current_releases = get_current_releases()

        @output.puts "Changed releases:"

        old_releases.each do |release_name, release|
            next unless current_releases.key?(release_name)
            current_release = current_releases[release_name]
            next if release[:version] == current_release[:version]

            @output.puts "  #{release_name} (#{release[:version]} >>> #{current_releases[release_name][:version]})"
            run_fissile_diff(release[:path], current_release[:path])
        end
    end

    def run_fissile_diff(path_a, path_b)
        system("env -u FISSILE_LIGHT_OPINIONS -u FISSILE_DARK_OPINIONS -u FISSILE_RELEASE -u FISSILE_ROLE_MANIFEST fissile diff --light-opinions #{@empty_opinions_path} --dark-opinions #{@empty_opinions_path} --release='#{path_a},#{path_b}' | sed 's/^/    /'", out: @output, err: @output)
    end
end
