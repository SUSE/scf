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
  image_re = %r{^#{common_part}$}
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

    pulled_images = pull_images(containers)
    # Don't upgrade containers we can't get a target image for
    containers.reject!{|c| !pulled_images.find{|p| p == c[:Names]}}

    containers.each do |container|
      containerID = container[:ID]
      m = @@container_re.match(container[:Image])
      repository = m[:repository]
      pathStart  = m[:pathStart]
      rest       = m[:rest]
      newImage = "#{@target_repository || repository}#{pathStart}#{@target_version}#{rest}:#{@target_tag}"
      # Shut down the current container
      if m[:rest] == "-runner"
        # Evacuate the DEAs
        res = do_cmd("docker exec kill -s USR2 #{containerID}")
        #return if !res
      end

      data = JSON.parse(`docker inspect #{container[:Names]}`)[0]
        
      do_cmd("docker stop #{containerID}")
      do_cmd("docker kill #{containerID}")
      do_cmd("docker rename #{container[:Names]} #{container[:Names]}-#{@new_name_suffix}")
      @containers_to_delete << containerID

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

  private

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

  def pull_images(containers)
    threads = []
    images = []
    mutex = Mutex.new
    $stderr.puts("About to pull #{containers.size} new images...")
    containers.each do |container|
      m = @@container_re.match(container[:Image])
      if !m
        $stderr.puts("Not a container: #{container[:Image]}")
        next
      end
      #threads << Thread.new(container, match) do |c, m|
        repository = m[:repository]
        pathStart  = m[:pathStart]
        version    = m[:version]
        rest       = m[:rest]
        tag        = m[:tag]
        newImage = "#{@target_repository || repository}#{pathStart}#{@target_version}#{rest}:#{@target_tag}"
        if do_cmd("docker pull #{newImage}")
          mutex.lock
          images << container[:Names]
          mutex.unlock
        end
      #end
    end # containers loop
    #threads.each(&:join)
    $stderr.puts("... Done pulling #{containers.size} new images.")
    return images
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
    
end

options = {:target_version => "222"}
opts = OptionParser.new
opts.on("-t", "--target-version VAL", String) { |val|   options[:target_version] = val }
opts.on("-g", "--target-tag VAL", String) { |val|   options[:target_tag] = val }
opts.on("-r", "--target-repository VAL", String) { |val|   options[:target_repository] = val }
opts.on("-d", "--role-dependencies PATH", String) { |val|   options[:role_dependencies] = val }
opts.parse(ARGV)

def process_dependencies(options)
  dep_path = options.delete(:role_dependencies)
  if !dep_path
    $stderr.puts("Warning: No --role-dependencies option given")
    return nil
  end
  return YAML.load_file(dep_path)['order'].reject{|x| x == "hcf-consul-server"}
end

options[:ordered_roles] = process_dependencies(options)

c = Node.new(options)
images, containers = c.get_current_images_and_containers
c.upgrade_images(images, containers)
