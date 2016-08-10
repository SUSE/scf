param (
    [string]$hcfIdlPath = "C:\hcf-instance.json"
)

$ErrorActionPreference = "Stop"

$wd="C:\diego-kit"
mkdir -f $wd
cd $wd


# Prepare network

$hcfIdl = (cat $hcfIdlPath) | ConvertFrom-Json

$instanceId = $hcfIdl.'instance_id'
$clusterDnsAffix = "svc.cluster.hcp"

Set-DnsClientGlobalSetting -SuffixSearchList @($instanceId + "." + $clusterDnsAffix)
Clear-DnsClientCache

$coreIpAddress = (Resolve-DnsName –Name "consul-int" -Type A)[0].IpAddress
$machineIp = (Find-NetRoute -RemoteIPAddress $coreIpAddress)[0].IPAddress

# 1.2.3.4 is used by rep and metron to discover the IP address to be announced to the diego cluster
# https://github.com/pivotal-golang/localip/blob/ca5f12419a47fe0c8547eea32f9498eb6e9fe817/localip.go#L7
route delete 1.2.3.4
route add 1.2.3.4 $coreIpAddress -p


## Download and install global dependencies

echo "Downloading localwall"
curl -Verbose -UseBasicParsing -OutFile $wd\localwall.exe https://s3-us-west-1.amazonaws.com/clients.als.hpcloud.com/ro-artifacts/als-win-localhost-filter-artifacts/babysitter-23-2016-07-13_10-01-51/localwall.exe

# VC redist are used by cf-iis8-buildpack
echo "Downloading VC 2013 and 2015 redistributable"
mkdir -Force "$wd\vc2013", "$wd\vc2015"
curl -Verbose -UseBasicParsing  -OutFile "vc2013\vcredist_x86.exe"  https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe
curl -Verbose -UseBasicParsing  -OutFile "vc2013\vcredist_x64.exe"  https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe
curl -Verbose -UseBasicParsing  -OutFile "vc2015\vc_redist.x86.exe"  https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x86.exe
curl -Verbose -UseBasicParsing  -OutFile "vc2015\vc_redist.x64.exe"  https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe

echo "Installing VC 2013 and 2015 redistributable"
start -Wait "vc2013\vcredist_x86.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "vc2013\vcredist_x64.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "vc2015\vc_redist.x86.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "vc2015\vc_redist.x64.exe"  -ArgumentList "/install /passive /norestart"

echo "Installing Windows Features"
Install-WindowsFeature  Web-Webserver, Web-WebSockets, AS-Web-Support, AS-NET-Framework, Web-WHC, Web-ASP
Install-WindowsFeature  Web-Net-Ext, Web-AppInit # Extra features for the cf-iis8-buildpack


## Download installers

$gardenVersion = "v0.153"
echo "Downloading GardenWindows.msi $gardenVersion"
curl  -UseBasicParsing  -Verbose  -OutFile $wd\GardenWindows.msi  https://github.com/cloudfoundry/garden-windows-release/releases/download/$gardenVersion/GardenWindows.msi

echo "Downloading diego-installer.exe"
curl  -UseBasicParsing -OutFile $wd\diego-installer.exe https://s3-us-west-1.amazonaws.com/clients.als.hpcloud.com/ro-artifacts/hcf-windows-release-artifacts/babysitter-19-2016-07-19_09-17-46/diego-installer.exe -Verbose


## Enable disk quota

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


## HCF setting

$hcfSettings = New-Object System.Collections.Hashtable

$hcfIdl.'parameters' | % { $hcfSettings.Add( $_.name, $_.value -replace ( "\\n", "`n") ) }

$env:DIEGO_INSTALL_DIR = "c:\diego"
$env:DIEGO_USER_PASSWORD = "changeme1234!"

$env:REP_CELL_ID = $env:COMPUTERNAME
$env:DIEGO_CELL_IP = $machineIp
$env:STACKS = "win2012r2;windows2012R2"
$env:REP_ZONE = "windows"
$env:REP_MEMORY_MB = "auto"

$env:CONSUL_SERVER_IP = "consul-int"
$env:CONSUL_ENCRYPT_KEY = $hcfSettings.'consul-encryption-keys'
$env:CONSUL_CA_CRT = $hcfSettings.'consul-ca-cert'
$env:CONSUL_AGENT_CRT = $hcfSettings.'consul-agent-cert'
$env:CONSUL_AGENT_KEY = $hcfSettings.'consul-agent-key'

$env:BBS_ADDRESS = "https://diego-database-int:8889"
$env:BBS_CA_CRT = $hcfSettings.'bbs-ca-crt'
$env:BBS_CLIENT_CRT = $hcfSettings.'bbs-client-crt'
$env:BBS_CLIENT_KEY = $hcfSettings.'bbs-client-key'

$env:ETCD_CLUSTER = "http://etcd-int:4001"
$env:LOGGRAGATOR_SHARED_SECRET = $hcfSettings.'loggregator-shared-secret'
$env:LOGGREGATOR_JOB = $env:COMPUTERNAME
$env:LOGGRAGATOR_INDEX = 0


$gardenProduct = gwmi win32_product | ? {$_.name -match 'GardenWindows'}
if ($gardenProduct) {
  echo "Uninstalling existing GardenWindows. `nDetails: $gardenProduct"
  $gardenProduct.Uninstall()
}

echo "Installing Garden-Windows"
cmd /c  msiexec /passive /norestart /i $wd\GardenWindows.msi MACHINE_IP=$machineIp


echo "Installing Diego-Windows"
cmd /c "$wd\diego-installer.exe /Q"
