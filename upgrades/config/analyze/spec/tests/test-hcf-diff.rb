#!/usr/bin/env ruby

require "json"

require "test/unit"
$root_dir = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
$:.push(File.join($root_dir, "lib"))

require "differ/compare"
include Differ::Compare
require "differ/utils"
include Differ::Utils
require "differ/yamls"
include Differ::Yamls

class TestHcfDiff < Test::Unit::TestCase
  def initialize(*args)
    super(*args)
    @test_dir = File.join($root_dir, "spec")
    @fixtures_dir = File.join($root_dir, "spec", "fixtures")
  end

  def test_lexer
    str = <<-EOF
build = "latest-master"
# Obsolete
# registry_host="15.125.71.0:5000"

# Use default = 217
#cf-release = "217"

# Set this to the number of DEA hosts you wish to create
dea_count = 1
EOF
    a = tf_lexer(str)
    assert_equal(6, a.size)
    assert_equal(%w/build = "latest-master" dea_count = 1/, a)
    assert_equal("latest-master", dequote(a[2]))
  end

  def test_bash_unescape_special_chars
    s = %q{"abc\def\"ghi\$jkl\`mno"}
    exp = %q{"abc\def"ghi$jkl`mno"}
    assert_equal(exp, bash_unescape(s))
  end

  def test_bash_dont_unescape_other_chars
    s = %q{"abc\'def\#ghi\3jkl\&mno"}
    assert_equal(s, bash_unescape(s))
  end

  def bash_dont_unescape_single_quoted_string
    s = %q{'a\`b'"d\`"e\$f'h\$j"m\$n"'p\"q'r\$s"}
    exp = %q{'a\`b'"d`"e$f'h\$j"m$n"'p\"q'r$s}
    assert_equal(exp, bash_unescape(s))
  end

  def bash_unescape_compound_string
    s = %q{'abc\\def\"ghi\$jkl\`mno'}
    assert_equal(s, bash_unescape(s))
  end

  def test_merge_results
    a1 = {add:{'a' => 1}, drop:{'b' => 2}, change:{'c' => 3}}
    a2 = {add:{'d' => 4}, drop:{'e' => 5}, change:{'f' => 6}}
    a1c = a1.clone
    a2c = a2.clone
    merge_results(a1, a2)
    assert_equal(a2, a2c)
    [:add, :drop, :change].each do |k|
      assert_equal(a1c[k].merge(a2c[k]), a1[k])
    end
    assert_equal(a1c.keys, a1.keys)
  end

  def test_is_compound
    assert(is_compound?([]))
    assert(is_compound?({}))
    assert(!is_compound?(""))
    assert(!is_compound?(Date.new))
  end

  def test_hcf_diffs
    ov = "overrides.tfvars"
    pvars = {"template_file.domain.rendered" => "1.2.3.4.xip.io"}
    old_configs = get_configs(File.join(@fixtures_dir, "hcf-cf-v217"), ov, pvars)
    new_configs = get_configs(File.join(@fixtures_dir, "hcf-cf-v222"), ov, pvars)
    results = compare_configs(old_configs, new_configs)
    str_results = JSON.dump(results).chomp
    basename = "hcf-217-222-diffs.txt"
    exp_file = File.join(@fixtures_dir, "results", basename)
    exp_results = IO.read(exp_file).chomp
    if str_results != exp_results
      actual_file = "/tmp/#{basename}"
      File.open(actual_file, 'w'){|fd| fd.write(str_results)}
      assert_equal(exp_results, str_results, "Compare files #{exp_file} vs #{actual_file}")
    else
      assert(true)
    end
  end
end
