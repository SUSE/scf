#!/usr/bin/env ruby

require "json"

require "test/unit"
$root_dir = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
$:.push(File.join($root_dir, "lib"))

require "differ/compare"
include Differ::Compare

require "differ/yamls"
include Differ::Yamls

class TestJobConfigDiffs < Test::Unit::TestCase
  def initialize(*args)
    super(*args)
    @test_dir = File.join($root_dir, "spec")
    @fixtures_dir = File.join($root_dir, "spec", "fixtures")
  end

  def test_same_closed_specs_217_22
    parent_dir = File.join(@fixtures_dir, "cf-release-217-222-tgz-same")
    results = compare_cf_specs(File.join(parent_dir, "cf-v217"),
                               File.join(parent_dir, "cf-v222"))
    assert_equal({:add=>[], :drop=>[], :change=>[]}, results)
  end
  
  def test_same_opened_specs_217_22
    parent_dir = File.join(@fixtures_dir, "cf-release-217-222-opened-same")
    results = compare_cf_specs(File.join(parent_dir, "cf-v217"),
                               File.join(parent_dir, "cf-v222"))
    assert_equal({:add=>[], :drop=>[], :change=>[]}, results)
  end

  def compare_json_results(results, basename)
    str_results = JSON.dump(results).chomp
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

  def test_diff_closed_specs_217_222
    results = compare_cf_specs(File.join(@fixtures_dir, "cf-release-217-tgz"),
                               File.join(@fixtures_dir, "cf-release-222-tgz"))
    basename = "cf-217-222-tgz-specs.txt"
    compare_json_results(results, basename)
  end

  def test_diff_open_specs_217_222
    results = compare_cf_specs(File.join(@fixtures_dir, "cf-release-217-opened"),
                               File.join(@fixtures_dir, "cf-release-222-opened"))
    basename = "cf-217-222-opened-specs.txt"
    compare_json_results(results, basename)
  end
end
    
    
