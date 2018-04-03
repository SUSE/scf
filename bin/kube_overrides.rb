require 'yaml'
require 'json'

namespace, domain, kube_config = ARGV

configmap = %x(kubectl get configmap secrets-config --namespace #{namespace} -o json)
configmap = JSON.parse(configmap)['data']
current_secrets_name = configmap['current-secrets-name']

secrets = %x(kubectl get secret secrets --namespace #{namespace} -o json)
secrets = JSON.parse(secrets)['data']

generated = %x(kubectl get secret #{current_secrets_name} --namespace #{namespace} -o json)
generated = JSON.parse(generated)['data']

obj = YAML.load_file(kube_config)
obj['spec']['containers'].each do |container|
  container['env'].each do |env|
    unless domain.empty?
      value = env['value']

      case env['name']
      when 'DOMAIN'
        value = domain
      when 'TCP_DOMAIN'
        value = "tcp.#{domain}"
      when 'UAA_HOST'
        value = "uaa.#{domain}"
      end

      env['value'] = value.to_s
    end

    if env['valueFrom'] && env['valueFrom']['secretKeyRef']
      name = env['name'].downcase.gsub('_', '-')
      if generated.has_key?(name) && (secrets[name].nil? || secrets[name].empty?)
        env['valueFrom']['secretKeyRef']['name'] = current_secrets_name
      end
    end
  end
end
puts obj.to_json
