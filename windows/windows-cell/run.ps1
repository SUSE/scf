$wd=$PSScriptRoot
$ErrorActionPreference = "Stop"

echo "Installing Diego-Windows"
cmd /c "$wd\diego-installer.exe /Q"

echo "Installing VC 2013 and 2015 Update 1 redistributable"
start -Wait "vcredist_x86.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "vcredist_x64.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "VC_redist.x86.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "VC_redist.x64.exe"  -ArgumentList "/install /passive /norestart"

echo "Installing Windows Features"
Install-WindowsFeature -Name Web-Webserver, Web-WebSockets, AS-Web-Support, AS-NET-Framework, Web-WHC, Web-ASP -Source D:\sources\sxs
Install-WindowsFeature -Name Web-Net-Ext, Web-AppInit -Source D:\sources\sxs # Extra features for the cf-iis8-buildpack 


echo "Enableing disk quota"
fsutil quota enforce C:


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

$routeIP = (Resolve-DNSName $env:DIEGO_DATABASE_HOST -Type A)[0].IPAddress
$machineIp = (Find-NetRoute -RemoteIPAddress $routeIP)[0].IPAddress

msiexec /passive /norestart /i $wd\GardenWindows.msi MACHINE_IP=$machineIp