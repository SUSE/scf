require 'zlib'
require 'archive/tar/minitar'
require 'yaml'

module Differ
  module Yamls
    
    def get_fake_yaml
      return {'properties'=>{}, 'jobs'=>{}}
    end
    
    def get_yamls(dir)
      yamls = {}
      if is_opened_dir(dir)
        Dir.glob("#{dir}/jobs/*/job.MF").each do |old_job_file|
          dir_part = File.basename(File.dirname(old_job_file))
          yamls[dir_part] = [old_job_file, YAML.load_file(old_job_file)]
        end
      else
        Dir.glob("#{dir}/jobs/*.tgz").each do |old_tgz|
          Zlib::GzipReader.open(File.open(old_tgz, 'rb')) do |gz_reader|
            reader = Archive::Tar::Minitar::Reader.open(gz_reader)
            reader.each_entry do |entry|
              if entry.name["job.MF"]
                yamls[File.basename(old_tgz).sub(/\.tgz$/, '')] = [old_tgz, YAML.load(entry.read)]
                break
              end
            end
            reader.close
          end
        end
      end
      yamls
    end

    def yaml_final_encode(s)
      return YAML.dump(s).sub(/\A---\s+/, "").sub(/\s+\z/, "")
    end

    def yaml_encode(s)
      case s
        when Hash
        return yaml_final_encode(Hash[s.map{|k, v| [k, v.nil? ? "null" : v]}])
        when Array
        return yaml_final_encode(s)
        when nil
        return "null"
        when true,false,Integer,Float
        return "#{s}"
        else
        return s
      end
    end
    
  end
end
