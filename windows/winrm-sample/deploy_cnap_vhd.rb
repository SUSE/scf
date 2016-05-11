require 'winrm'
require 'tempfile'

current_dir = File.expand_path(File.dirname(__FILE__))
endpoint = "" # 'http://52.58.146.151:5985/wsman'
user = "" # 'Administrator'
password = "" # 'password'

if endpoint.nil? || endpoint.empty?
  endpoint = ENV['WINRM_ENDPOINT']
end
if user.nil? || user.empty?
  user = ENV['WINRM_USER']
end
if password.nil? || password.empty?
  password = ENV['WINRM_PASSWORD']
end

winrm = WinRM::WinRMWebService.new(endpoint, :negotiate, :user => user, :pass => password, :basic_auth_only => true)
ps_script = File.join(current_dir, 'deploy_cnap_vhd.ps1')

tmpfile = Tempfile.new("tempfile").path

File.open(tmpfile, 'w') do |fo|
  ARGV.each do|a|
    vars = a.split("=")
    next if vars.length != 2
    key = vars[0]
    val = vars[1]
    fo.puts "$env:#{key} = \"#{val}\""
  end
  
  File.foreach(ps_script) do |li|
    fo.puts li
  end
end

script = File.open(tmpfile, 'r')

winrm.create_executor do |executor|
  executor.run_powershell_script(script) do |stdout, stderr|
    STDOUT.print stdout
    STDERR.print stderr
  end
end