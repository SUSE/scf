#!/usr/bin/env ruby
##
# The purpose of this script is to assess which of the publicly
# available charts for the databases supported by minibroker will work
# with SCF.

# Configuration
# - Fixed location: `stable` helm repository
# - Configurable:   work directory for state
# - Configurable:   SCF namespace
# - Configurable:   Cluster Admin Password
# - Configurable:   Operation mode (full, incremental)

require 'fileutils'
require 'net/http'
require 'open3'
require 'optparse'
require 'uri'
require 'yaml'

# Global option for error handling in run, capture
$opts = { errexit: true }

@top = File.dirname(File.dirname(File.dirname(File.absolute_path(__FILE__))))

def main
  config
  base_statistics

  @assessed = 0
  @skipped = 0
  state

  engines.each do |engine|
    master_index[engine].each do |chart|
      enginev       = chart['appVersion']
      chartv        = chart['version']
      chartlocation = chart['urls'].first

      # We are ignoring all the entries for which we do not have the
      # engine version. Because that is the plan id later, therefore
      # required.
      next unless enginev

      next if skip_chart(engine, enginev, chartv)
      assess_chart(chart, engine, enginev, chartv, chartlocation)
      @assessed += 1
    end
  end

  rewind
  if @skipped
    puts "#{"Skipped".cyan}:  #{@skipped}"
  end
  if @assessed
    puts "#{"Assessed".cyan}: #{@assessed}"
  end
end

def config
  @workdir     = File.join(@top, '_work/mb-chart-assessment')
  @namespace   = "cf"
  @auth        = "changeme"
  @incremental = false

  OptionParser.new do |opts|
    opts.banner = "Usage: assess-minibroker-charts [options]"
    opts.on("-wPATH", "--work-dir=PATH", "Set work directory for state and transients") do |v|
      @workdir = v.to_s
    end
    opts.on("-nNAME", "--namespace=NAME", "Set SCF namespace") do |v|
      @namespace = v.to_s
    end
    opts.on("-pPASS", "--password=PASS", "Set cluster admin password") do |v|
      @auth = v.to_s
    end
    opts.on("-i", "--incremental", "Activate incremental mode") do |v|
      @incremental = true
    end
  end.parse!

  puts "Configuration".cyan
  puts "  - Namespace: #{@namespace.blue}"
  puts "  - Password:  #{@auth.blue}"
  puts "  - Mode:      #{mode.blue}"
  puts "  - Top:       #{@top.blue}"
  puts "  - Work dir:  #{@workdir.blue}"
end

def mode
  if @incremental
    "incremental, keeping previous data"
  else
    "fresh, clearing previous data"
  end
end

def engines
  # Add new engines here. May also have to change the test case
  # selection if the name of the test case in the brain tests deviates
  # from the name of the database engine. We assume a name of the form
  # `<nnn>_minibroker_<engine>_test`.
  [
    'mariadb',
    'mongodb',
    'postgresql',
    'redis'
  ]
end

def master_index
  unless @master
    puts "#{"Retrieving".cyan} master index ..."
    @master = helm_index(stable)['entries']
  end
  @master
end

def helm_index(location)
    uri = URI.parse (location + "/index.yaml")
    res = Net::HTTP.get_response uri

    # Debugging, save index data.
    File.write(File.join(@workdir, 'index-location.txt'), uri)
    File.write(File.join(@workdir, 'index.yaml'), res.body)

    YAML.load (res.body)
end

def base_statistics
  engines.each do |engine|
    # Debugging. Save per-engine indices.
    File.write(File.join(@workdir, "e-#{engine}.yaml"), master_index[engine].to_yaml)

    # We are ignoring all the entries for which we do not have the
    # engine version. Because that is the plan id later, therefore
    # required.
    puts "#{"Extracting".cyan} engine #{engine.blue}: #{master_index[engine].select do |chart|
         chart ['appVersion']
    end.length.to_s.cyan}"
  end
end

def state
  # Memoized
  unless @state
    # Look for state only in incremental mode. Do not fail if missing,
    # just fall back to regular mode, starting with empty state.
    if @incremental && File.exists?(statepath)
      @state = YAML.load_file(statepath)
    else
      @state = {}
    end
    # State schema:
    # <engine>.<version>.works	:: boolean
    # <engine>.<version>.app	:: string
    #
    # version is chart version  (`version`)
    # app     is engine version (`appVersion`)
  end
  @state
end

def state_save(engine, enginev, chartv, success)
  @state[engine] = {} unless @state[engine]
  @state[engine][chartv] = {
    'app'   => enginev,
    'works' => success,
  }
  File.write(statepath, @state.to_yaml)
end

def skip_chart(engine, enginev, chartv)
  if @incremental && state[engine] && state[engine][chartv]
    @skipped += 1
    rewind
    write "Skipping #{engine} #{enginev} #{chartv}"
    # delay to actually see the output ?
    true
  else
    false
  end
end

def assess_chart (chart, engine, enginev, chartv, chartlocation)
  log_start(engine, enginev, chartv)

  rewind
  write "  - #{engine.blue} #{enginev.blue}, chart #{chartv.blue} ..."

  separator " helm repo setup ..." do
    @the_repo = helm_repo_setup(chart, engine, chartlocation)

    if @the_repo
      " helm repo #{"up".green},"
    else
      state_save(engine, enginev, chartv, false)
      " helm repo #{"start failed".repo}, likely a patch failure"
    end
  end

  if @the_repo
    separator " testing ..." do
      success = do_test(@the_repo, engine)

      state_save(engine, enginev, chartv, success)
      if success
        archive_save(engine, chartv)
        regenerate_working_index
        " testing #{"OK".green},"
      else
        " testing #{"FAIL".red},"
      end
    end

    # clear leftovers, service & broker parts, ignoring errors.
    separator " post assessment, clearing service & broker state ..." do
      set errexit: false do
        run "cf marketplace"
        stdout, _, _ = capture "cf service-brokers"
        matches = stdout.match(/(minibroker-[^ 	]*)/)
        if matches
          broker = matches[1]
          run "cf", "purge-service-offering", "-f", engine
          run "cf", "delete-service-broker",  "-f", broker
        end
      end
      ""
    end

    separator " helm repo shutdown ..." do
      helm_repo_shutdown
      " helm repo #{"down".blue},"
    end
  end

  puts " done"
  log_done
end

def helm_repo_shutdown
  # After a test we shut the local helm repository down again. We ignore failures.
  set errexit: false do
    run "cf", "delete",       "-f", helm_app
    run "cf", "delete-space", "-f", "mb-charting"
    run "cf", "delete-org",   "-f", "mb-charting"
  end
  FileUtils.remove_dir(appdir, force = true)
end

def helm_repo_setup(chart, engine, chartlocation)
  # Assemble and run node-env app serving the helm repository.
  # I. Copy original app into fresh directory
  FileUtils.remove_dir(appdir, force = true)
  FileUtils.cp_r(appsrc, appdir)

  # II. Change app name to something more suitable
  m = YAML.load_file (manifest)
  m['applications'][0]['name'] = helm_app
  File.write(manifest, m.to_yaml)

  # III. Write remote helm chart to local file
  get_engine_chart(chartlocation)

  # IV. Patch local chart archive. Stop on failure
  return "" unless sucessfully_patched_chart(engine)

  # V. Place index (*) and patched chart.
  #    (*) With proper chart archive reference
  File.write(chart_index, make_index_yaml(chart, engine, chart_ref))
  FileUtils.cp(archive_patched, archive_app)

  # VI. Start repository (push app)

  run "cf", "api", "--skip-ssl-validation", target
  run "cf", "auth", "admin", @auth
  run "cf create-org   mb-charting"
  run "cf target    -o mb-charting"
  run "cf create-space mb-charting"
  run "cf target    -o mb-charting"
  run "cf enable-feature-flag diego_docker"

  FileUtils.cd(appdir) do
    run "cf", "push", "-n", helm_app
  end

  # Report location
  helm_repo
end

def get_engine_chart(chartlocation)
    uri = URI.parse (chartlocation)
    res = Net::HTTP.get_response uri
    File.write(archive_orig, res.body)
end

def sucessfully_patched_chart(engine)
  patch = patch_of(engine)
  if File.exists?(patch)
    # Patch required - setup, unpack, modify, repack, cleanup
    # setup
    tmp = File.join(@workdir, "tmp")
    FileUtils.remove_dir(tmp, force = true)
    FileUtils.mkdir_p(tmp)

    # unpack
    run "tar", "xfz", archive_orig, "-C", tmp

    # modify
    FileUtils.cd (File.join(tmp, engine, "templates")) do
      @patch_stdout, _, @patch_status = capture "patch", "--verbose", "-i", patch
    end
    unless @patch_status.success?
      # Check for `Reversed` and accept that, else fail
      unless @patch_stdout =~ /Reversed/
        return false
      end
    end

    # repack
    run "tar", "cfz", archive_patched, "-C", tmp, engine

    # cleanup
    FileUtils.remove_dir(tmp)
  else
    # No patch, just copy, cannot fail
    FileUtils.cp(archive_orig, archive_patched)
  end
  true
end

def make_index_yaml (chart, engine, newloc)
  index = {
    'apiVersion' => 'v1',
    'entries'    => {
      engine => []
    },
  }
  index['entries'][engine] << chart.dup
  # Relocate
  index['entries'][engine][0]['urls'] = [ newloc ]
  # Go does not parse the timestamp format emitted by ruby.
  # See if using a string is ok.
  index['entries'][engine][0]['created'] = fixed_time
  index.to_yaml
end

def do_test(the_repo, engine)
  _, _, status = capture tester, "acceptance-tests-brain",
	                 "env.INCLUDE=#{testcase_of(engine)}",
	                 "env.KUBERNETES_REPO=#{the_repo}",
	                 "env.VERBOSE=true"
  status.success?
end

# ......................................................................
# Engine-specific constructed values

def testcase_of(engine)
  return "_minibroker_postgres" if engine =~ /postgresql/
  "_minibroker_#{engine}"
end

def patch_of(engine)
  File.join(@top, "tooling/mb-chart-assessment/patches", "#{engine}.patch")
end

def archive_save(engine, chartv)
  dst = File.join(archive_saved, "#{engine}-#{chartv}.tgz")
  FileUtils.mkdir_p(archive_saved)
  FileUtils.cp(archive_patched, dst)
end

def regenerate_working_index
  # Extract the chart blocks for all working charts from the master,
  # patch the archive location to refer to the internal dev helm
  # repository used by the brain tests, and save to a file.
  working = {}
  engines.each do |engine|
    working[engine] = []
    master_index[engine].each do |chart|
      chartv = chart['version']
      next unless @state && @state[engine] && @state[engine][chartv] && @state[engine][chartv]['works']
      new = chart.dup
      new['created'] = fixed_time
      new['urls'] = "#{mbbt_repository}/#{engine}-#{chartv}.tgz"
      working[engine] << new
    end
  end
  File.write(working_saved, working.to_yaml)
end

# ......................................................................
# Various (semi)constant values, mostly paths and the like

def mbbt_repository
  "https://minibroker-helm-charts.s3.amazonaws.com/kubernetes-charts"
end

def fixed_time
  "2018-07-30T17:55:01.330815339Z"
end

def stable
  "https://kubernetes-charts.storage.googleapis.com"
end

def helm_app
  "chart-under-test"
end

def chart_in_app
  "chart.tgz"
end

def statepath
  @statepath = File.join(@workdir, 'results.yaml') unless @statepath
  @statepath
end

def appdir
  @appdir = File.join(@workdir, "charts") unless @appdir
  @appdir
end

def working_saved
  @wsaved = File.join(archive_saved, 'index.yaml') unless @wsaved
  @wsaved
end

def archive_saved
  @asaved = File.join(@workdir, 'ok') unless @asaved
  @asaved
end

def archive_orig
  @aunpatched = File.join(@workdir, 'archive-orig.tgz') unless @aunpatched
  @aunpatched
end

def archive_patched
  @apatched = File.join(@workdir, 'archive-patched.tgz') unless @apatched
  @apatched
end

def manifest
  @manifest = File.join(appdir, "manifest.yml") unless @manifest
  @manifest
end

def chart_index
  @chartindex = File.join(appdir, "index.yaml") unless @chartindex
  @chartindex
end

def archive_app
  @aapp = File.join(appdir, chart_in_app) unless @aapp
  @aapp
end

def domain
  @domain, _, _ = capture "kubectl get pods -o json --namespace \"#{@namespace}\" api-group-0 | jq -r '.spec.containers[0].env[] | select(.name == \"DOMAIN\").value'" unless @domain
  @domain
end

def tester
  @brain = File.join(@top, "make/tests") unless @brain
  @brain
end

def appsrc
  @appsrc = File.join(@top, "src/scf-release/src/acceptance-tests-brain/test-resources/node-env") unless @appsrc
  @appsrc
end

def helm_repo
  @helmrepo = "http://#{helm_app}.#{domain}" unless @helmrepo
  @helmrepo
end

def target
  @target = "https://api.#{domain}" unless @target
  @target
end

def chart_ref
  @chartref = "#{helm_repo}/#{chart_in_app}" unless @chartref
  @chartref
end

# ......................................................................
# Logging, and terminal cursor control
# First three commands snarfed from test utils and modified to suit
# (divert output into log file)

# Set global options.
# If a block is given, the options are only active in that block.
def set(opts={})
    if block_given?
        old_opts = $opts.dup
        $opts.merge! opts
        yield
        $opts.merge! old_opts
    else
        $opts.merge! opts
    end
end

def run(*args)
  opts = $opts.dup
  opts.merge! args.last if args.last.is_a? Hash
  _, _, status = capture(*args)
  return unless opts[:errexit]
  unless status.success?
    # Print an error at the failure site
    puts "Command exited with #{status.exitstatus}".red
    fail "Command exited with #{status.exitstatus}"
  end
end

def capture(*args)
  _print_command(*args)
  args.last.delete :errexit if args.last.is_a? Hash
  stdout, stderr, status = Open3.capture3(*args)
  log stdout
  log stderr.red
  return stdout.chomp, stderr.chomp, status
end

# Internal helper: print a command line in the log.
def _print_command(*args)
    cmd = args.dup
    cmd.shift if cmd.first.is_a? Hash
    cmd.pop if cmd.last.is_a? Hash
    log "+ #{cmd.join(" ")}".bold
    log "\n"
end

def separator(text)
  sepline = "____________________________________________________________ #{text} ___"
  log "\n#{sepline.magenta}\n"
  write text
  message = yield
  left text.length
  eeol
  write message
end

def log_start(engine,enginev,chartv)
  enginedir = File.join(@workdir, engine)
  @log = File.join(enginedir, "#{enginev}-#{chartv}.log")
  FileUtils.mkdir_p(enginedir)
  FileUtils.rm_f(@log)
  FileUtils.touch(@log)
end

def log(text)
  # append to log file @log
  # https://stackoverflow.com/questions/27956638/how-to-append-a-text-to-file-succinctly/27956730
  #File.write(@log, text, File.size(@log), mode: 'a')
  File.write(@log, text, mode: 'a')
end

def log_done
  @log = nil
end

def write (text)
  print text
  $stdout.flush
end

# Move cursor n character towards the beginning of the line
def left(n=1)
  print "\033[#{n}D"
end

# Erase (from cursor to) End Of Line
def eeol
  print "\033[K"
end

# Move to beginning of line and erase
def rewind
  print "\r"
  eeol
end

# ......................................................................
# Colorization support.
class String
  def red
    "\033[0;31m#{self}\033[0m"
  end

  def green
    "\033[0;32m#{self}\033[0m"
  end

  def yellow
    "\033[0;33m#{self}\033[0m"
  end

  def blue
    "\033[0;34m#{self}\033[0m"
  end

  def magenta
    "\033[0;35m#{self}\033[0m"
  end

  def cyan
    "\033[0;36m#{self}\033[0m"
  end

  def bold
    "\033[0;1m#{self}\033[0m"
  end
end

# ......................................................................
main
