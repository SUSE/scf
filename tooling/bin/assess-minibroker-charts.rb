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

require 'yaml'
require 'optparse'
require 'net/http'
require 'uri'
require 'fileutils'

# brain tests, test utils -- various forms of running things, with and
# without capture, aboprt on error or not, etc.
require_relative "../../src/scf-release/src/acceptance-tests-brain/test-scripts/testutils.rb"

@top = File.dirname(File.dirname(File.dirname(File.absolute_path(__FILE__))))

def main
  config
  master
  base_statistics

  @assessed = 0
  @skipped = 0
  state
  
  engines.each do |engine|
    master[engine].each do |chart|
      enginev       = chart['appVersion']
      chartv        = chart['version']
      chartlocation = chart['urls'].first  

      # We are ignoring all the entries for which we do not have the
      # engine version. Because that is the plan id later, therefore
      # required.
      next unless enginev
      
      next if skip_chart(engine, enginev, chartv)
      assess_chart(engine, enginev, chartv, chartlocation)
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
    opts.on("-w", "--work-dir", "Set work directory for state and transients") do |v|
      @workdir = v.to_s
    end
    opts.on("-n", "--namespace", "Set SCF namespace") do |v|
      @namespace = v.to_s
    end
    opts.on("-p", "--password", "Set cluster admin password") do |v|
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

def master
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
    File.write(File.join(@workdir, 'index.yaml'), res.body)
    YAML.load (res.body)
end

def stable
  "https://kubernetes-charts.storage.googleapis.com"
end

def base_statistics
  engines.each do |engine|
    # We are ignoring all the entries for which we do not have the
    # engine version. Because that is the plan id later, therefore
    # required.

    # Debugging. Save engine index.
    File.write(File.join(@workdir, "e-#{engine}.yaml"), master[engine].to_yaml)
    
    puts "#{"Extracting".cyan} engine #{engine.blue}: #{master[engine].select do |chart|
         chart ['appVersion']
    end.length.to_s.cyan}"
  end
end

def state
  unless @state
    if @incremental
      results = File.join(@workdir, 'results.yaml')
      if File.exists? results
        @state = YAML.load_file(results)
      else
        @state = {}
      end
    else
      @state = {}
    end
    # <engine>.<version>.works	:: boolean
    # <engine>.<version>.app	:: string `appVersion`.
    # version     is chart version
    # app'Version is engine version
  end
  @state
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

def assess_chart (engine, enginev, chartv, chartlocation)
  log_start(engine, enginev, chartv)
  
  rewind
  write "  - #{engine.blue} #{enginev.blue}, chart #{chartv.blue} ..."

  sep " helm repo setup ..." do
    # 2.b Generate a helm repo index for the specific engine and chart.
    # get and patch chart
    # start a helm repository server
    # TODO START REPO (make index, patch chart, push app)
    # helm repo red(start failed), likely a patch failure
    # helm repo green (up),
    " helm repo #{"up".green},"
  end

  sep " testing ..." do
    # select test case
    # TODO run test
    # testing red (FAIL)
    # testing green (OK)
    # TODO update state. save to disk
    " testing #{"OK".green},"
  end

  sep " post assessment, clearing service & broker state ..." do
    # TODO clear broker stuff
    ""
  end

  sep " helm repo teardown ..." do
    # TODO repo teardown
    # 
    " helm repo #{"down".blue},"
  end

  puts " done"
  log_done
end

def sep (text)
  log "\n....................................... #{text}\n"
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
end

# ......................................................................
main
