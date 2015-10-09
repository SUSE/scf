require 'yaml'
opinions = YAML.load_file 'opinions.yml'

roles = []

opinions['jobs'].each do |job|
  jobs = job['templates'].collect{|t|t['name']}
  jobs.delete 'metron_agent'
  jobs.collect!{|j|{'name' => j}}
  role = {
    'name' => job['name'].sub(/_z\d$/, ''),
    'jobs' => jobs
  }
  roles << role
end

roles.sort!{|a,b| a['name'] <=> b['name']}
roles.uniq!

puts({'roles' => roles}.to_yaml)