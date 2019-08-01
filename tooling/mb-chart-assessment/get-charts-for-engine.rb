require 'yaml'
engine = ARGV[0]
index  = ARGV[1]
values = YAML.load_file(index)
puts values['entries'][engine].to_yaml
