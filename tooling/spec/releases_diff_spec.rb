require 'releases_diff'

RSpec.describe ReleasesDiff do

    it 'calculates the root of the source tree correctly' do
        expect(ReleasesDiff.git_root).to eq(File.expand_path('../../', File.dirname(__FILE__)))
    end

    before(:each) do
        @reader, @writer = IO::pipe
        @diff = ReleasesDiff.new('tooling/test_assets/manifest.yaml', @writer)

        @diff.save_old_manifest()
        @diff.fissile_validate_old_releases()
        @diff.fissile_validate_current_releases()
    end

    context "with identical manifests" do
        it "saves the manifest to a temp file" do 
            expect(File).to exist(@diff.old_manifest)
        end

        it "loads old releases into a hash" do
            releases = @diff.get_old_releases()
            expect(releases.count).to_not be(0)
        end

        it "loads current releases into a hash" do
            releases = @diff.get_current_releases()
            expect(releases.count).to_not be(0)
        end

        it "prints unchanged releases" do
            @diff.print_unchanged_releases()
            output = @reader.read_nonblock(1024 * 1024)

            expect(output).to include("Unchanged releases:\n  nginx (1.12.2)")
        end
    end

    context "with different manifests" do
        it "prints new releases" do
            @diff.current_manifest = File.join(File.expand_path('../', File.dirname(__FILE__)), 'test_assets/manifest_added.yaml')
            @diff.print_added_releases()
            output = @reader.read_nonblock(1024 * 1024)

            expect(output).to include("Added releases:\n  ntp (2)")
        end

        it "prints removed releases" do
            @diff.current_manifest = File.join(File.expand_path('../', File.dirname(__FILE__)), 'test_assets/manifest_removed.yaml')
            @diff.print_removed_releases()
            output = @reader.read_nonblock(1024 * 1024)

            expect(output).to include("Removed releases:\n  nginx (1.12.2)")
        end

        it "prints unchanged releases" do
            @diff.current_manifest = File.join(File.expand_path('../', File.dirname(__FILE__)), 'test_assets/manifest_added.yaml')

            @diff.print_unchanged_releases()
            output = @reader.read_nonblock(1024 * 1024)

            expect(output).to include("Unchanged releases:\n  nginx (1.12.2)")
        end

        it "prints changed releases" do
            @diff.current_manifest = File.join(File.expand_path('../', File.dirname(__FILE__)), 'test_assets/manifest_changed.yaml')
            @diff.fissile_validate_current_releases()

            @diff.print_changed_releases()
            output = @reader.read_nonblock(1024 * 1024)

            expect(output).to include("Changed releases:\n  nginx (1.12.2 >>> 1.13.12)")
            expect(output).to include("Added keys:\n      drain")
        end
    end
end
