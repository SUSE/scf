#!/usr/bin/env ruby

require 'json'

if ARGV.length < 2
  puts 'Usage: diego-cell-count-modifier.rb <amount> <sd-file> <sid-file>'
  exit 1
end

CELL_REGEX = /diego-cell-([0-9]+)/
GRAPH_REGEX = /garden-graph-([0-9]+)/

def scale_service_definition(sd, amount)
  sd['components'].delete_if do |c|
    match = CELL_REGEX.match(c['name'])
    match && match[1].to_i >= amount
  end

  sd['volumes'].delete_if do |v|
    match = GRAPH_REGEX.match(v['name'])
    match && match[1].to_i >= amount
  end

  sd['sdl_version'] += "-#{amount}cell"

  sd['parameters'].push(
    'name' => 'workaround-ca-private-key',
    'description' => 'placeholder',
    'required' => true,
    'secret' => true,
    'default' => nil,
    'generator' => {
      'id' => 'cacert',
      'generate' => {
        'type' => 'CACertificate',
        'value_type' => 'private_key'
      }
    }
  )

  puts JSON.pretty_generate(sd)
end

def scale_instance_definition(sid, amount)
  sid['scaling'].delete_if do |s|
    match = CELL_REGEX.match(s['component'])
    match && match[1].to_i >= amount
  end

  sid['sdl_version'] += "-#{amount}cell"

  sid['parameters'].push('name' => 'workaround-ca-private-key',
                         'value' => 'not-required')

  sid['version'] = sid['sdl_version']

  puts JSON.pretty_generate(sid)
end

amount = ARGV.shift.to_i
file_name_in = ARGV.shift

definition = JSON.parse(File.read(file_name_in))
if definition.key? 'instance_id'
  STDERR.puts "Service Instance:   #{file_name_in}"
  scale_instance_definition definition, amount
else
  STDERR.puts "Service Definition: #{file_name_in}"
  scale_service_definition definition, amount
end
