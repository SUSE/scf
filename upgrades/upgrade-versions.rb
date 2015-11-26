#!/usr/bin/env ruby

require 'json'
require 'open3'
require 'optparse'
require 'securerandom'
require 'yaml'

VERSION="0.1"

# Node-based upgrades

class Node
  common_part = '(?<repository>[\d\.]+:\d+)(?<pathStart>/hcf/cf-v)(?<version>\d+)(?<rest>-.*)'
  @@container_re = %r{#{common_part}:(?<tag>.*)$}
  def initialize(opts)
    @target_repository = opts.delete(:target_repository)
    @target_version = opts.fetch(:target_version)
    @target_tag = opts.delete(:target_tag) || "latest"
    opts.delete(:target_version)
    @roles_to_delete = opts.delete(:roles_to_delete) || []
    @roles_to_add = opts.delete(:roles_to_add) || []
    @ordered_roles = opts.delete(:ordered_roles)
    @opts = opts
    @new_name_suffix = "-#{SecureRandom.urlsafe_base64[0..8]}"
    @containers_to_delete = []
    @images_to_remove_by_id = []
    
  end
  
  def get_current_images_and_containers
    all_containers_str = `docker ps -a --format='{{.ID}}<!>{{.Image}}<!>{{.Names}}<!>{{.Status}}'`.split(/\n/)
    all_containers = all_containers_str.
      map { |s| Hash[[:ID,:Image,:Names,:Status].zip(s.split("<!>"))]}.
      reject { |container| container[:Status].start_with?("Exited")}.
      reject { |container| %r{hcf/cf-v(\d+)-} =~ container[:Image] && $1.to_i >= @target_version.to_i }

    raw_images = `docker images`.split(/\n/).drop(1)
    images = raw_images.map { |s|
      parts = s.split(/\s+/, 4).take(3)
      Hash[[:Repository, :Tag, :ID].zip(parts)]
    }.reject {|image| image[:Repository] !~ /cf-v\d/}

    all_containers.reject! {|container|
      !images.find{|image| image[:Image] == container[:Repository]}
    }
      
    return [images, all_containers]
  end
    
  def upgrade_images(images, containers)
    if @ordered_roles
      containers = sort_by_precedence(containers)
    end
    # Handle hcf-consul-server specially
    idx = containers.find_index{|c| c[:Names] == "hcf-consul-server"}
    if idx
      consul_server_container = containers.delete_at(idx)
    else
      consul_server_container = nil
    end

    @container_data = {} # Hash of inspect data for each container
    stop_and_rename_containers(containers.reverse)
    if consul_server_container
      system("docker network disconnect hcf #{consul_server_container[:ID]}")
    end
    stop_and_rename_container(consul_server_container) if consul_server_container
    # About to restart docker, so everything should be gone now
    add_docker_insecure_registry

    if consul_server_container
      restart_container(consul_server_container, @container_data["hcf-consul-server"]["Config"]["Image"])
      cid = (`docker ps | awk '/hcf-consul-server/ { print $1 }'` || "").chomp
      if cid.size > 0
        system("docker network connect hcf #{cid}")
      end
    end
    restart_containers(containers)
    clean_up
  end

  private

  def add_docker_insecure_registry
    orig_text = IO.read("/etc/default/docker")
    if orig_text[@target_repository]
      return
    end
    idx = orig_text.rindex("--insecure-registry")
    if !idx
      return
    end
    idx2 = idx + "--insecure-registry".size
    connector = orig_text[idx2]
    if %r{\d+(?:\.\d+){3}/\d}.match(orig_text, idx2)
      # If we find a CIDR address like 15.124.0.0/14 we don't need to update
      return
    end
    new_text = "#{orig_text[0...idx]} --insecure-registry#{connector}#{@target_repository} #{orig_text[idx..-1]}"
    # Save a backup
    File.open("/tmp/default-docker.orig", "w") { |fd| fd.write(orig_text) }
    File.open("/tmp/default-docker.new", "w")  { |fd| fd.write(new_text) }
    system("sudo cp /tmp/default-docker.new /etc/default/docker")
    system("sudo service docker restart")
  end

  def clean_up
    if @containers_to_delete.size > 0
      $stderr.puts("Deleting #{@containers_to_delete.size} old containers...")
      @containers_to_delete.unshift("rm")
      spawn("docker", *@containers_to_delete)
    end
    if @images_to_remove_by_id.size > 0
      $stderr.puts("Deleting #{@images_to_remove_by_id.size} old images...")
      @images_to_remove_by_id.unshift("rmi")
      spawn("docker", *@images_to_remove_by_id)
    end
  end

  def do_cmd(cmd, complain=true)
    the_stdout = nil
    the_stderr = nil
    Open3.popen3(cmd) do |stdin, stdout, stderr|
      the_stderr = stderr.read
      the_stdout = stdout.read
    end
    if complain && the_stderr.size > 0
      $stderr.print("Errors: #{the_stderr}\n")
    end
    if complain && the_stdout.size > 0
      $stderr.print("Running command #{cmd} ===>:\n#{the_stdout}\n")
    end
    return the_stderr.size == 0
  end
    
  def sort_by_precedence(containers)
    # Your basic transform/sort/pick pattern
    value_by_role = Hash[@ordered_roles.zip((0...@ordered_roles.size))]
    valued_containers = containers.map{|c|
      name = c[:Names]
      if value_by_role[name]
        [value_by_role[name], c]
      elsif c[:Names] =~ /cf-runner-\d/
        [value_by_role["cf-runner-#"], c]
      else
        [999, c]
      end
    }
    return valued_containers.sort.map{|x| x[1]}
  end

  def restart_container(container, newImage)
    data = @container_data[container[:Names]]
    args = data['Args']
    host_config = data['HostConfig']
    dns_servers = host_config['Dns']
    restart_policy = host_config['RestartPolicy']

    case restart_policy["Name"]
    when "unless-stopped", "no", "always", /^on-failure(?::\d)?/
      restart_cmd_part = "--restart=#{restart_policy["Name"]}"
    else
      abort("Unexpected restart-policy of #{restart_policy["Name"]}") #XXX
    end
    privileged = host_config['Privileged']
    role_name = data['Name']
    role_name = (role_name[0] == "/") ? role_name[1..-1] : role_name
    
    mounts = data['Mounts']
    config = data['Config']
    env = Hash[config["Env"].map{|s|s.split('=', 2)}]
    
    cmd_parts = ["docker run",
                 "-d",
                 "--net=#{host_config['NetworkMode']}",
                 "-e 'HCF_NETWORK=#{env['HCF_NETWORK']}'",
                 "-e 'HCF_OVERLAY_GATEWAY=#{env['HCF_OVERLAY_GATEWAY']}'",
                 "--privileged=#{privileged}",
                 "--cgroup-parent=#{host_config["CgroupParent"]}",
                 restart_cmd_part]
    cmd_parts += dns_servers.map{|d| "--dns=#{d}"}
    cmd_parts << "--name #{role_name}"
    cmd_parts += host_config['Binds'].map{|b| "-v #{b}"} if host_config['Binds']

    port_bindings = host_config["PortBindings"]
    if port_bindings
      bindings = []
      port_bindings.each do |key, values|
        if key =~ %r{^(\d+)/tcp}
          values.each do |value|
            if value["HostIp"].size > 0
              $stderr.puts("**** Ignoring a port bound to ip #{value["HostIp"]}")
              next
            end
            bindings << "-p #{$1}:#{value["HostPort"]}"
          end
        end
      end
      cmd_parts += bindings
    end
    cmd_parts += ["-t", newImage]
    cmd_parts += args
    cmd = cmd_parts.join(" ")
    res = do_cmd(cmd)
    if !res
      $stderr.puts("Might want to keep the old image around and restart it")
    end
    # Mark the old image for deletion
    image = images.find{|i| container[:Image].start_with?(i[:Repository])}
    if image
      @images_to_remove_by_id << image[:ID]
    end
  end

  def restart_containers(containers)
    containers.each do |container|
      containerID = container[:ID]
      m = @@container_re.match(container[:Image])
      if !m
        $stderr.puts("Skip container #{container}")
        next
      end
      repository = m[:repository]
      pathStart  = m[:pathStart]
      rest       = m[:rest]
      newImage = "#{@target_repository || repository}#{pathStart}#{@target_version}#{rest}:#{@target_tag}"
      restart_container(container, newImage)
    end
  end

  def stop_and_rename_container(container)
    containerID = container[:ID]      

    @container_data[container[:Names]] = JSON.parse(`docker inspect #{container[:Names]}`)[0]
        
    do_cmd("docker stop #{containerID}")
    do_cmd("docker kill #{containerID}")
    do_cmd("docker rename #{container[:Names]} #{container[:Names]}-#{@new_name_suffix}")
    @containers_to_delete << containerID
  end

  def stop_and_rename_containers(containers)
    containers.reverse.each do |container|
      containerID = container[:ID]
      m = @@container_re.match(container[:Image])
      if !m
        $stderr.puts("Skip container #{container}")
        next
      end
      # Shut down the current container
      if m[:rest] == "-runner"
        # Evacuate the DEAs
        res = do_cmd("docker exec kill -s USR2 #{containerID}")
        #return if !res
      end
      stop_and_rename_container(container)
    end
  end
    
end

options = {:target_version => "222"}
opts = OptionParser.new
opts.on("-t", "--target-version VAL - REQUIRED", String) { |val|   options[:target_version] = val }
opts.on("-g", "--target-tag VAL - REQUIRED", String) { |val|   options[:target_tag] = val }
opts.on("-r", "--target-repository VAL - REQUIRED", String) { |val|   options[:target_repository] = val }
opts.on("-d", "--role-dependencies PATH - REQUIRED", String) { |val|   options[:role_dependencies] = val }
opts.parse(ARGV)
if !options[:target_repository] || !options[:target_version] || !options[:target_tag] || !options[:role_dependencies]
  $stderr.puts("Not enough args: #{opts}")
  exit(1)
end

def process_dependencies(options)
  dep_path = options.delete(:role_dependencies)
  if !dep_path
    $stderr.puts("Warning: No --role-dependencies option given")
    return nil
  end
  return YAML.load_file(dep_path)['order']
end

options[:ordered_roles] = process_dependencies(options)

c = Node.new(options)
images, containers = c.get_current_images_and_containers
c.upgrade_images(images, containers)
