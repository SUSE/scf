#!/var/vcap/packages/ruby-2.3/bin/ruby

# This assumes STDIN is JSON and evaluates ARGV[0] on it

require 'json'
require 'ostruct'

def to_ostruct(obj)
  case obj
  when Hash then OpenStruct.new(Hash[obj.map { |k, v| [k, to_ostruct(v)] }])
  when Array then obj.map { |x| to_ostruct(x) }
  else obj
  end
end

data = to_ostruct(JSON.load(STDIN))
puts eval("data." + ARGV[0])
