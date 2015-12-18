require 'yaml'

require 'differ/utils'
include Differ::Utils

require 'differ/yamls'
include Differ::Yamls

module Differ
  module Compare
    
    def compare_cf_specs(old_cf_dir, new_cf_dir, verbose=false)
      old_yamls = get_yamls(old_cf_dir)
      new_yamls = get_yamls(new_cf_dir)
      old_yaml_keys = old_yamls.keys
      new_yaml_keys = new_yamls.keys
      results = {add:{}, drop:{}, change:{}}
      (new_yaml_keys - old_yaml_keys).each do |k|
        puts "New job: #{k}" if verbose
        new_results = fix_job_manifest_results(compare_files(get_fake_yaml,
                                                             new_yamls[k][1]))
        merge_results(results, new_results)
        if verbose
          puts "#{k}:"
          pp new_results
        end
      end
      (old_yaml_keys - new_yaml_keys).each do |k|
        puts "Deleted job: #{k}" if verbose
        new_results = fix_job_manifest_results(compare_files(old_yamls[k][1],
                                                             get_fake_yaml))
        merge_results(results, new_results)
        if verbose
          puts "#{k}:"
          pp new_results
        end
      end
      (old_yaml_keys & new_yaml_keys).each do |k|
        #  puts("**** yaml_file1:#{old_yamls[k][0]}")
        new_results = fix_job_manifest_results(compare_files(old_yamls[k][1],
                                                             new_yamls[k][1]))
        merge_results(results, new_results)
        if verbose
          puts "#{k}:"
          pp new_results
        end
      end
      results
    end
    
    def compare_dirs(old_dir, new_dir, filename, prefix, verbose=false, limit=-1)
      old_yaml = YAML.load_file(File.join(old_dir, filename))
      new_yaml = YAML.load_file(File.join(new_dir, filename))
      return compare_files(old_yaml, new_yaml, prefix, limit)
    end
    
    def compare_files(old_config, new_config, prefix="", limit=-1)
      results = {add:{}, drop:{}, change:{}}
      diff_hashes(prefix, old_config['properties'] || {}, new_config['properties'] || {}, results, limit)
      
      old_jobs = Hash[old_config.fetch('jobs', {}).map{|x|[x['name'], x]}]
      new_jobs = Hash[new_config.fetch('jobs', {}).map{|x|[x['name'], x]}]
      
      old_keys = old_jobs.keys
      new_keys = new_jobs.keys
      roots = {}
      (old_keys | new_keys).each do |key|
        job = old_jobs[key] || new_jobs[key]
        name = job['name'].sub(/_z\d+$/,"")
        next if roots[name]
        roots[name] = true
        name = "#{prefix}/#{name}" if prefix.size > 0
        diff_hashes(name, old_jobs.fetch(key, {}).fetch("properties", {}),
                    new_jobs.fetch(key, {}).fetch("properties", {}),
                    results, limit)
      end
      results
    end

    def compare_configs(a, b, verbose=false)
      results = {add:{}, drop:{}, change:{}}
      dropped_keys = a.keys - b.keys
      added_keys = b.keys - a.keys
      dropped_keys.each do |k|
        results[:drop][k] = a[k]
      end
      added_keys.each do |k|
        results[:add][k] = b[k]
      end
      (a.keys & b.keys).each do |k|
        v1 = a[k]
        v2 = b[k]
        if v1 != v2
          results[:change][k] = [v1, v2]
        end
      end
      results
    end
    
    def diff_hashes(root, p1, p2, results, limit)
      old_keys = p1.keys
      new_keys = p2.keys
      (old_keys | new_keys).sort.each do |k|
        if !p1.has_key?(k)
          if limit == 0 || p2[k].class != Hash
            results[:add]["#{root}/#{k}"] = yaml_encode(p2[k])
          else
            diff_hashes("#{root}/#{k}", {}, p2[k], results, limit - 1)
          end
        elsif !p2.has_key?(k)
          if limit == 0 || p1[k].class != Hash
            results[:drop]["#{root}/#{k}"] = yaml_encode(p1[k])
          else
            diff_hashes("#{root}/#{k}", p1[k], {}, results, limit - 1)
          end
        else
          old_val = p1[k]
          new_val = p2[k]
          if old_val == new_val
            # do nothing
          elsif old_val.is_a?(Hash) && new_val.is_a?(Hash)
            if limit == 0
              results[:change]["#{root}/#{k}"] = [yaml_encode(old_val),
                                                  yaml_encode(new_val)]
            else
              diff_hashes("#{root}/#{k}", old_val, new_val, results, limit - 1)
            end
          elsif is_compound?(old_val) || is_compound?(new_val)
            results[:drop]["#{root}/#{k}"] = yaml_encode(old_val)
            results[:add]["#{root}/#{k}"] = yaml_encode(new_val)
          else
            results[:change]["#{root}/#{k}"] = [yaml_encode(old_val),
                                                yaml_encode(new_val)]
          end
        end
      end
    end

    def fix_job_results(results)
      Hash[results.map { |k, v| [fix_job_key(k), v]}]
    end

    def fix_job_key(k)
      root, _, ktype = k.rpartition('/')
      pfx = case ktype
            when "description", "descritpion"
              "hcf/descriptions"
            when "default"
              "hcf/spec/cf"
            else
              abort("Unexpected key type #{ktype} in key:#{k}")
            end
      pfx + root.gsub('.', '/')
    end
    
    def fix_job_manifest_results(results)
      Hash[results.map{|k, v|[k, fix_job_results(v)]}]
    end

    def get_configs(dir, override_file, predefined_vars)
      variables = get_variables(dir, override_file)
      #TODO: Handle backslash-ending lines only if we add them
      configs = {}
      setter = %r{^\s*/opt/hcf/bin/set-config\s+\$CONSUL\s+(\S+)\s+(.*)(\\?)$}
      varref = %r@\$\{var\.([\w\.\_\-]+)\}@
      xref   = %r@\$\{([\w\.\_\-]+)\}@
      Dir.glob("#{dir}/**/*.tf").each do |tf_file|
        IO.readlines(tf_file).each do |line|
          line2 = line.chomp
          m = setter.match(line2)
          if m
            configs[m[1]] = bash_unescape(m[2].gsub(varref){|s| variables[$1] || s}.
                                          gsub(xref){|s| predefined_vars[$1] || s})
          end
        end
      end
      configs
    end
    
    def get_variables(dir, override_file)
      vars = {}
      Dir.glob("#{dir}/**/*.tf").each do |tf_file|
        words = tf_lexer(IO.read(tf_file))
        while (i = words.find_index("variable"))
          words.slice!(0, i + 1)
          default_posn = words.find_index("default")
          end_brace_posn = words.find_index("}")
          if default_posn && end_brace_posn && \
            words[1] == "{" && default_posn < end_brace_posn && \
            words[default_posn + 1] == "=" && \
            words[default_posn + 2] != "{"  # Ignore compound values
            vars[dequote(words[0])] = dequote(words[default_posn + 2])
          end
        end
      end

      if override_file.nil?
        ovf = nil
      elsif File.exist?(override_file)
        ovf = override_file
      elsif File.exist?(File.join(dir, override_file))
        ovf = File.join(dir, override_file)
      else
        abort("Can't find override file #{override_file} in #{dir}")
      end
      return vars if !ovf
      words = tf_lexer(IO.read(ovf))
      # This parser is simpler because override files have less syntax.
      # Just find all the '=' and they should be in an <<a = b>> context
      lim1 = words.size - 1
      words.each_index do |i|
        if words[i] == '=' && i > 0 && i < lim1
          vars[words[i - 1]] = words[i + 1]
        end
      end
      vars
    end
    
  end
end
