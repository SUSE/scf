require 'yaml'
require 'json'

release, kube_config = ARGV.shift(2)

helm_values = YAML.load %x(helm get values --all #{release})
helm_info = YAML.load %x(helm list --output yaml #{release})
namespace = helm_info['Releases'].last['Namespace']

configmap = %x(kubectl get configmap secrets-config --namespace #{namespace} -o json)
configmap = JSON.parse(configmap)['data']
current_secrets_name = configmap['current-secrets-name']

secrets = %x(kubectl get secret secrets --namespace #{namespace} -o json)
secrets = JSON.parse(secrets)['data']

generated = %x(kubectl get secret #{current_secrets_name} --namespace #{namespace} -o json)
generated = JSON.parse(generated)['data']

overrides = Hash.new
ARGV.each do |arg|
  k, v = arg.split('=', 2)
  overrides[k.split('.')] = v
end

clusterRoles = Hash.new
%x(kubectl get ClusterRole --output=jsonpath={@.items[*].metadata.name}).split.each do |clusterRole|
  clusterRoles[clusterRole] = true
end

YAML.load_stream (IO.read(kube_config)) do |obj|
  case obj['kind'].downcase
  when 'pod'
    if obj['spec']
      obj['spec']['containers'].each do |container|
        container['env'].each do |env|
          if env['valueFrom']
            # Downward API; check if it's from a secret
            if env['valueFrom']['secretKeyRef']
              name = env['name'].downcase.gsub('_', '-')
              if generated.has_key?(name) && (secrets[name].nil? || secrets[name].empty?)
                env['valueFrom']['secretKeyRef']['name'] = current_secrets_name
              end
            end
          elsif helm_values['env'].has_key? env['name']
            # Helm setting
            env['value'] = helm_values['env'][env['name']].to_s
          else
            # Missing default
            env['value'] = ''
          end
        end

        overrides.each do |k, v|
          child = container
          k[0...-1].each do |elem|
            child[elem] ||= {}
            child = child[elem]
          end
          if k[0...1] == %w(env)
            # Deal with the environment list specially, because the syntax isn't what
            # humans normally want.
            # The environment is actually in a list of hashes with "name" and "value"
            # keys.  Erase any elements with the same name, and then append it.
            child.reject! do |elem|
              elem['name'] == k.last
            end
            child << {
              'name'  => k.last,
              'value' => v,
            }
          else
            # Normal key/value override, e.g. to change the image pull policy
            child[k.last] = v
          end
        end
      end
    end

  when 'clusterrole'
    roleName = "#{namespace}-cluster-role-#{obj['metadata']['name']}"
    obj['metadata']['name'] = roleName
    clusterRoles[roleName] = true
    STDERR.puts "Will create cluster role #{obj['metadata']['name']}"

  when 'clusterrolebinding'
    if obj['roleRef']['kind'] == 'ClusterRole'
      # Prefer the namespaced role ref name
      roleRefName = "#{namespace}-cluster-role-#{obj['roleRef']['name']}"
      roleRefName = obj['roleRef']['name'] unless clusterRoles.has_key? roleRefName
      unless clusterRoles.has_key? roleRefName
        # Cluster role does not exist
        STDERR.puts "Warning: cluster role #{roleRefName} does not exist"
        next
      end

      obj['metadata']['name'] = "#{namespace}-#{obj['metadata']['name']}"
      obj['roleRef']['name'] = roleRefName
      obj['subjects'].each do |subject|
        subject['namespace'] = namespace if subject.has_key? 'namespace'
      end
    end
  end
  puts obj.to_yaml
end
