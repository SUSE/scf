$wd=$PSScriptRoot
$ErrorActionPreference = "Stop"

echo "Installing VC 2013 and 2015 redistributable"
start -Wait "$PSScriptRoot\vcredist_x86.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "$PSScriptRoot\vcredist_x64.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "$PSScriptRoot\vc_redist.x86.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "$PSScriptRoot\vc_redist.x64.exe"  -ArgumentList "/install /passive /norestart"

echo "Installing Windows Features"
Install-WindowsFeature -Name Web-Webserver, Web-WebSockets, AS-Web-Support, AS-NET-Framework, Web-WHC, Web-ASP -Source D:\sources\sxs
Install-WindowsFeature -Name Web-Net-Ext, Web-AppInit -Source D:\sources\sxs # Extra features for the cf-iis8-buildpack


echo "Enabling disk quota"
fsutil quota enforce C:

## Disable negative DNS client cache

New-Item 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -Force | `
  New-ItemProperty -Name MaxNegativeCacheTtl -PropertyType "DWord" -Value 1 -Force

Clear-DnsClientCache

## Configure firewall

echo "Configuring Windows Firewall"

# Snippet source: https://github.com/cloudfoundry/garden-windows-release/blob/master/scripts/setup.ps1#L134
$admins = New-Object System.Security.Principal.NTAccount("Administrators")
$adminsSid = $admins.Translate([System.Security.Principal.SecurityIdentifier])

$LocalUser = "D:(A;;CC;;;$adminsSid)"
$otherAdmins = Get-WmiObject win32_groupuser |
  Where-Object { $_.GroupComponent -match 'Administrators' } |
  ForEach-Object { [wmi]$_.PartComponent }

foreach($admin in $otherAdmins)
{
  $ntAccount = New-Object System.Security.Principal.NTAccount($admin.Name)
  $sid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
  $LocalUser = $LocalUser + "(A;;CC;;;$sid)"
}

Remove-NetFirewallRule -Name CFAllowAdmins -ErrorAction Ignore
New-NetFirewallRule -Name CFAllowAdmins -DisplayName "Allow admins" `
  -Description "Allow admin users" -RemotePort Any `
  -LocalPort Any -LocalAddress Any -RemoteAddress Any `
  -Enabled True -Profile Any -Action Allow -Direction Outbound `
  -LocalUser $LocalUser

Set-NetFirewallProfile -All -DefaultInboundAction Allow -DefaultOutboundAction Block -Enabled True

$routeIP = "1.2.3.4"
$machineIp = (Find-NetRoute -RemoteIPAddress $routeIP)[0].IPAddress

echo "Configuring WFP localhost filtering rules"

& "$wd\localwall.exe" cleanup

& "$wd\localwall.exe" add $machineIp 32 8301 Administrators # Consul rule
& "$wd\localwall.exe" add 127.0.0.1  8  8400 Administrators # Consul rule
& "$wd\localwall.exe" add 127.0.0.1  8  8500 Administrators # Consul rule

& "$wd\localwall.exe" add 127.0.0.1  8  3457 Administrators # Metron rule
& "$wd\localwall.exe" add $machineIp 32 6061 Administrators # Metron rule

& "$wd\localwall.exe" add $machineIp 32 1800 Administrators # Rep rule

& "$wd\localwall.exe" add 127.0.0.1  8  9241 Administrators # Garden rule

& "$wd\localwall.exe" add 127.0.0.1  8  1788 Administrators # Containerizer rule


echo "Installing Garden-Windows"
cmd /c  msiexec /passive /norestart /i $wd\GardenWindows.msi MACHINE_IP=$machineIp

echo "Installing Diego-Windows"
cmd /c "$wd\diego-installer.exe /Q"
