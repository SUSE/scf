#!/usr/bin/env ruby

require 'open3'
require 'yaml'

def lookup_nested(hash, key)
    fragments = key.split('.')
    frag = fragments[0]

    unless hash.has_key?(frag)
        return nil
    end

    current = hash[frag]
    if fragments.length == 1
        return current
    end

    key = key.sub(/^#{frag}\./, '')
    lookup_nested(current, key)
end

def scrape_images(path)
  values_yaml = File.join(path, 'values.yaml')
  templates_dir = File.join(path, 'templates')

  values = YAML.load(File.read(values_yaml))
  templates = Dir.glob(File.join(templates_dir, '**/*'))

  images = []

  templates.each do |filename|
      File.read(filename).each_line do |line|
          # Check for a line that starts with image:
          match = line.match(/^\s*-?\s*image:\s*"?(.*?)"?$/)
          next if match.nil?

          # Parse and replace any helm templates
          images.push match[1].gsub(/{{\s*\.Values.([^}\s]+)\s*}}/) { lookup_nested(values, $1) }
      end
  end

  return images
end

def find_chart_dirs(path)
  return Dir.glob(File.join(path, '**/Chart.yaml'))
end

if ARGV.length == 0
  puts "Usage: #{File.basename($0)} <directory>"
  puts
  puts "Must supply a directory to be recursively searched for helm charts."
  exit 1
end

chart_dirs = find_chart_dirs(ARGV[0])
charts_images = chart_dirs.map { |dir| scrape_images(File.dirname(dir)) }

charts_images.each do |chart_images|
  chart_images.each do |image|
    puts "Caching #{image}"
    Open3.popen2e("docker pull #{image}") do |stdin, stdouterr, thread|
      stdin.close
      IO.copy_stream(stdouterr, STDOUT) # Copy until EOF which means its probably done
      thread.join                       # Wait until the process has exited and then close our pipe
      stdouterr.close
    end
  end
end
