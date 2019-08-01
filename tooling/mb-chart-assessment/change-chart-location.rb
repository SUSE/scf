require 'yaml'

values = YAML.load_file(ARGV[0])
engine = ARGV[1]
newloc = ARGV[2]

values['entries'][engine][0]['urls'] = [ newloc ]
puts values.to_yaml
