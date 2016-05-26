#!/usr/bin/env ruby

# https://github.com/masterzen/winrm
# (cat envs.ps1 && cat run-cnap-image.ps1 && echo "exit") | winrm -hostname 192.168.77.79 "powershell -NonInteractive -Command -"

require 'winrm'

current_dir = File.expand_path(File.dirname(__FILE__))
env_script = File.join(current_dir, 'envs.ps1')
ps_script = File.join(current_dir, 'run-cnap-image.ps1')

winrm_client = WinRM::WinRMWebService.new(
  'http://192.168.77.79:5985/wsman',
  :negotiate,
  :user => 'vagrant',
  :pass => 'vagrant',
  :basic_auth_only => true
)

begin

  shell_id = winrm_client.open_shell
  command_id = winrm_client.run_command(shell_id, 'powershell', "-NonInteractive -Command -")

  File.foreach(env_script) do |line|
    winrm_client.write_stdin(shell_id, command_id, "#{line}\r\n")
  end

  File.foreach(ps_script) do |line|
    winrm_client.write_stdin(shell_id, command_id, "#{line}\r\n")
  end

  winrm_client.write_stdin(shell_id, command_id, "exit\r\n")

  commandsOutput = winrm_client.get_command_output(shell_id, command_id) do |stdout, stderr|
    STDOUT.write stdout
    STDERR.write stderr
  end

  puts "Exit code #{commandsOutput[:exitcode]}"

rescue Interrupt
  puts "Interrupt received"

ensure
  puts "Closing WinRM shell"
  winrm_client.cleanup_command(shell_id, command_id)
  winrm_client.close_shell(shell_id)
end
