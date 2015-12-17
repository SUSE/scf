module Differ
  module Utils
    
    def merge_results(old_hash, new_hash)
      [:add, :drop, :change].each do |k|
        old_hash[k] += new_hash[k]
      end
    end
    
    def is_compound?(x)
      x.is_a?(Hash) || x.is_a?(Array)
    end
    
    # Are we working with an uncracked release-dir containing only .tgz files?
    def is_opened_dir(dir)
      return Dir.glob("#{dir}/jobs/*/job.MF").size > 0
    end
    
    def merge_results(old_results, new_results)
      old_results.each_key{|k| old_results[k] += new_results[k] }
    end
    
    def tf_lexer(s)
      # Quick-and-dirty lexer: return the tokens we're interested in.
      # Use capture-groups to make it easy to pull out the interesting parts
      ptn = %r@ ([\{\}=]) | ([\d\w\-\_\.]+) | ("(?:\\.|[^"]*)") | \s+ | \#.* | \n | . @x
      # We have an array of things like ["{",nil,nil], [nil, "default", nil], [nil, nil, nil]]
      # Pull out the saved words, and drop matches we aren't interested in
      return s.scan(ptn).map{|x|x.find{|y|y}}.compact
    end
    
    def dequote(s)
      s.sub(/^"/,"").sub(/"$/, "")
    end
    
  end
end
