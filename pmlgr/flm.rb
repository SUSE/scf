#!/usr/bin/env ruby
#
# flm.rb -- Filter Loggregator Massive quantities of chatter

require 'pp'

$ptn2 = %r{^(\w+):((?:\"(?:\\\"|.)*?\")|[^\s\"]+)\s*}
$ptn3 = %r{^(\w+):<(((?:\"(?:\\\"|.)*?\")|.)+?)>\s*}
$desiredEventType = %r{eventType:\s*(?:LogMessage|Error)\b}

$fields_to_skip = %w/origin deployment job index ip source_instance/
$values_to_skip = {"eventType" => "LogMessage" }

def skip(name, val)
  #$stderr.puts("skip: #{name}, val:#{val}")
  xval = $values_to_skip[name]
  return false if !xval
  if xval.is_a?(Regexp)
    return xval.match(val)
  else
    return xval == val
  end
end    

def process(line, o)
  while line.size > 0
    m = $ptn3.match(line)
    if m
      name, val = m[1], m[2]
      #puts "Name:#{name}, $fields_to_skip.find_index(name):#{$fields_to_skip.find_index(name)}"
      if !$fields_to_skip.find_index(name)
        o1 = {}
        o[name] = o1
        process(val, o1)
      end
      line = m.post_match
    elsif (m = $ptn2.match(line))
      name, val = m[1], m[2]
      #puts "Name:#{name}, $fields_to_skip.find_index(name):#{$fields_to_skip.find_index(name)}"
      if !$fields_to_skip.find_index(name) && !skip(name, val)
        o[m[1]] = m[2]
        #puts "[#{m[1]}][#{m[2]}]"
      end
      line = m.post_match
    else
      puts "Skipping char at #{line}\n"
      line.slice!(0)
    end
  end
end

def emit_hash(hash, indent)
  #$stderr.puts("hash:#{hash} (#{hash.class})")
  #$stderr.puts("hash.keys.sort:#{hash.keys.sort}")
  hash.keys.sort.each do |k|
    v = hash[k]
    print "#{k}:"
    if v.is_a?(Hash)
      print "\n"
      emit_hash(v, indent + k.size)
    else
      if k == 'timestamp' && v =~ /\d{19,}/
        v = Time.at(v.to_i / 1.0e9).gmtime
      end
      puts " #{v}"
    end
  end 
end

$stdin.each do |line|
  #puts "\n\n#{line.chomp}: part 1"
  if line["Hit Ctrl+c to exit"]
    break
  end
end

last_hash = {}
$stdin.each do |line|
  next if $desiredEventType.match(line).nil?
  #puts "\n\n#{line.chomp}: part 2"
  line.lstrip!
  o = {}
  process(line, o)
  if o.fetch("logMessage", {})["message"] =~ /^"Tick: \d+"$/
    # skip
  else
    if o['timestamp'] && o.fetch("logMessage", {})["timestamp"]
       o.delete('timestamp')
    end
    if o.keys.size == 1 && o.values[0].is_a?(Hash)
      o = o.values[0]
    end
    #puts "Final obj:#{o}"
    last_hash.delete("message")
    deleted_something = false
    o_orig = o.merge({}) # o.clone
    last_hash.each do |k, v|
      o[k] = '.' if o[k] == v
    end
    emit_hash(o, 0)
    last_hash = o_orig
    last_hash.delete('message') # Always keep this
    puts
  end
end
