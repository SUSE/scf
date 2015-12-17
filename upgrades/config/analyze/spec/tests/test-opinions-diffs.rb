#!/usr/bin/env ruby

require "json"

require "test/unit"
$root_dir = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
$:.push(File.join($root_dir, "lib"))

require 'differ/compare'
include Differ::Compare

class TestOpinionDiffs < Test::Unit::TestCase
  def initialize(*args)
    super(*args)
    @test_dir = File.join($root_dir, "spec")
    @fixtures_dir = File.join($root_dir, "spec", "fixtures")
    @old_dir = File.join(@fixtures_dir, "cf-v217")
    @new_dir = File.join(@fixtures_dir, "cf-v222")
  end
  
  def test_opinion_diffs
    results = compare_dirs(@old_dir, @new_dir, "opinions.yml", "hcf/opinions")
    str_results = JSON.dump(results).chomp
    basename = "opinions-217-222-diffs.txt"
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
  
  def test_dark_opinion_diffs
    results = compare_dirs(@old_dir, @new_dir, "dark-opinions.yml", "hcf/user")
    str_results = JSON.dump(results).chomp
    basename = "dark-opinions-217-222-diffs.txt"
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
