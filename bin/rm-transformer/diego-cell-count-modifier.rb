#!/usr/bin/env ruby

require 'json'

if ARGV.length < 2
  puts "Usage: twentyscale.rb <amount> <sd-file> <sid-file>"
  exit 1
end

CELL_REGEX = /diego-cell-([0-9]+)/
GRAPH_REGEX = /garden-graph-([0-9]+)/

def scale_service_definition(sd, amount)
  STDERR.puts "Deleting diego cells from sd"
  sd["components"].delete_if do |c|
    match = CELL_REGEX.match(c["name"])
    !match.nil? && match[1].to_i >= amount
  end
  STDERR.puts "Deleting garden volumes from sd"
  sd["volumes"].delete_if do |v|
    match = GRAPH_REGEX.match(v["name"])
    !match.nil? && match[1].to_i >= amount
  end

  STDERR.puts "Adjusting sd version name"
  sd["sdl_version"] += "-#{amount}cell"

  STDERR.puts "Happily applying hideous HSM hacks"
  sd["parameters"].push({
    "name" => "workaround-ca-private-key",
    "description" => "placeholder",
    "required" => true,
    "secret" => true,
    "default" => nil,
    "generator" => {
      "id" => "cacert",
      "generate" => {
        "type" => "CACertificate",
        "value_type" => "private_key"
      }
    }
  })

  puts JSON.pretty_generate(sd)
end

def scale_instance_definition(sid, amount)
  STDERR.puts "Deleting scaling params from sid"
  sid["scaling"].delete_if do |s|
    match = CELL_REGEX.match(s["component"])
    !match.nil? && match[1].to_i >= amount
  end

  STDERR.puts "Adjusting sid version name"
  sid["sdl_version"] += "-#{amount}cell"

  STDERR.puts "Happily applying hideous HSM hacks"
  sid["parameters"].push({
    "name" => "workaround-ca-private-key",
    "value" => "not-required"
  })
  sid["version"] = sid["sdl_version"]

  puts JSON.pretty_generate(sid)
end

amount = ARGV.shift.to_i
file_name_in = ARGV.shift

definition = JSON.parse(File.read(file_name_in))
if definition.has_key? 'instance_id'
  STDERR.puts "Service Instance:   #{file_name_in}"
  scale_instance_definition definition, amount
else
  STDERR.puts "Service Definition: #{file_name_in}"
  scale_service_definition definition, amount
end
