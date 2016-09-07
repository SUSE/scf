require 'yaml'
file = YAML.load_file('/var/vcap/packages/acceptance-tests-flight-recorder/config/role-manifest.yml')

roles_to_monit = []

file.each  do |key, item|
  if key == "roles"
     item.each do |role|
        if (role["run"]["flight-stage"] != "manual") && (role["type"] != "bosh-task") && (role["type"] != "docker")
        roles_to_monit << role["name"] + "-int"
        end
     end
     break
  end
end

File.open("/var/vcap/packages/acceptance-tests-flight-recorder/config/source_to_check.txt", "w+") do |f|
  f.puts(roles_to_monit)
end
