#!/usr/bin/env ruby

require 'winrm'
require 'tempfile'

current_dir = File.expand_path(File.dirname(__FILE__))
endpoint = ENV['WINRM_ENDPOINT']
user = ENV['WINRM_USER']
password = ENV['WINRM_PASSWORD']

if endpoint.nil? || endpoint.empty?
  endpoint = 'http://192.168.77.78:5985/wsman'
end
if user.nil? || user.empty?
  user = 'vagrant'
end
if password.nil? || password.empty?
  password = 'vagrant'
end

winrm = WinRM::WinRMWebService.new(endpoint, :negotiate, :user => user, :pass => password, :basic_auth_only => true)
ps_script = File.join(current_dir, 'deploy_cnap_vhd.ps1')

tmpfile = Tempfile.new("tempfile")

ARGV.each do|a|
  vars = a.split("=")
  next if vars.length != 2
  key = vars[0]
  val = vars[1]
  tmpfile.puts "$env:#{key} = \"#{val}\""
end

File.foreach(ps_script) do |li|
  tmpfile.puts li
end

tmpfile.flush

script = File.open(tmpfile.path, 'r')

winrm.create_executor do |executor|
  executor.run_powershell_script(script) do |stdout, stderr|
    STDOUT.print stdout
    STDERR.print stderr
  end
end

tmpfile.close(true)
