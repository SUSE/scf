require 'yaml'

engine  = ARGV[0]
enginev = ARGV[1]
chartv  = ARGV[2]
values = YAML.load_file(ARGV[3])

index = {
  'apiVersion' => 'v1',
  'entries'    => {
    engine => []
  },
}

values.each do |chart|
  next unless chart['appVersion'] && chart['appVersion'] == enginev
  next unless chart['version'] && chart['version'] == chartv
  index['entries'][engine] << chart
end

puts index.to_yaml
