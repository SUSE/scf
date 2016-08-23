param (
    [Parameter(Mandatory=$true)]
    [string]$hcfIdlPath
)

$ErrorActionPreference = "Stop"

Import-Module -DisableNameChecking "$PSScriptRoot\utils\cf-install-utils.psm1"

$wd="$PSScriptRoot\resources\diego-kit"

# Prepare network

$hcfIdl = Get-Content -Raw $hcfIdlPath | ConvertFrom-Json

$instanceId = $hcfIdl.'instance_id'
$clusterDnsAffix = "svc.cluster.hcp"

Set-DnsClientGlobalSetting -SuffixSearchList @($instanceId + "." + $clusterDnsAffix)
Clear-DnsClientCache

$hcfCompoentHostname = "consul-int"
$hcfCompoentIpAddress = (Resolve-DnsName -Name $hcfCompoentHostname -Type A)[0].IpAddress
$hcfCompoentRoute = (Find-NetRoute -RemoteIPAddress $hcfCompoentIpAddress)[0]
$advertisedMachineIp = $hcfCompoentRoute.IPAddress
$advertisedMachineInterfaceIndex = $hcfCompoentRoute.InterfaceIndex

SetInterfaceForLocalipGoPackage $advertisedMachineInterfaceIndex

echo "Installing VC 2013 and 2015 redistributable"
start -Wait "$wd\vc2013\vcredist_x86.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "$wd\vc2013\vcredist_x64.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "$wd\vc2015\vc_redist.x86.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "$wd\vc2015\vc_redist.x64.exe"  -ArgumentList "/install /passive /norestart"

IntalledRequiredWindowsFeatures
EnableDiskQuota
DisableNegativeDnsClientCache
ConfigureCellWindowsFirewall
ConfigureCellLocalwall "$wd\localwall.exe"

## HCF setting

$hcfSettings = New-Object System.Collections.Hashtable

$hcfIdl.'parameters' | % { $hcfSettings.Add( $_.name, $_.value -replace ( "\\n", "`n") ) }

$env:DIEGO_INSTALL_DIR = "c:\diego"
$env:DIEGO_USER_PASSWORD = "changeme1234!"

$env:REP_CELL_ID = $env:COMPUTERNAME
$env:DIEGO_CELL_IP = $advertisedMachineIp
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


UninstallGardenWindows

echo "Installing Garden-Windows"
cmd /c  msiexec /passive /norestart /i $wd\GardenWindows.msi MACHINE_IP=$advertisedMachineIp


echo "Installing Diego-Windows"
cmd /c "$wd\diego-installer.exe /Q"
