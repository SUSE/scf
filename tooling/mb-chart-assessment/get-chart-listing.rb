require 'yaml'

engine = ARGV[0]

values = YAML.load_file(engine)
exit if ! values

values.each do |chart|
  enginev = chart['appVersion']
  next unless enginev
  # We are ignoring all the entries for which we do not have the
  # engine version. Because that is the plan id later, therefore
  # required.
  chartv   = chart['version']
  location = chart['urls'].first
  
  puts "#{enginev} #{chartv} #{location}" if chart['appVersion']
end
