param (
    [Parameter(Mandatory=$true)]
    [string]$HCPInstanceId,
    [Parameter(Mandatory=$true)]
    [string]$CloudFoundryAdminUsername,
    [Parameter(Mandatory=$true)]
    [Security.SecureString]$CloudFoundryAdminPassword,
    [Parameter(Mandatory=$false)]
    [switch]$SkipSslValidation = $false
)

$CloudFoundryAdminPasswordClear = (New-Object System.Management.AUtomation.PSCredential('dummy',$CloudFoundryAdminPassword)).GetNetworkCredential().password

$ErrorActionPreference = "Stop"

Import-Module -DisableNameChecking "$PSScriptRoot\utils\cf-install-utils.psm1"

$wd="$PSScriptRoot\resources\diego-kit"

# Prepare network

$clusterDnsAffix = "cluster.hcp"

Set-DnsClientGlobalSetting -SuffixSearchList @($clusterDnsAffix, "$($HCPInstanceId).svc.$($clusterDnsAffix)")

#https://blogs.technet.microsoft.com/networking/2009/04/16/dns-client-name-resolution-behavior-in-windows-vista-vs-windows-xp/
REG add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v AppendToMultiLabelName /t REG_DWORD /d 1 /f | out-null
Restart-Service Dnscache
Clear-DnsClientCache

$hcfCompoentHostname = "consul"
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
ConfigureCellLocalwall "$wd\localwall.exe" $advertisedMachineIp

## HCF setting

$hcfSettings = GetConfigFromDemophon -Username $CloudFoundryAdminUsername -Password $CloudFoundryAdminPasswordClear -DemaphonEndpoint "https://demophon:8443" -SkipCertificateValidation $SkipSslValidation

## Generate REP Cert

rm -Force -Recurse -ErrorAction SilentlyContinue .\out
Write-Output $hcfSettings.REP_SERVER_KEY | Out-File rep.key -Encoding ascii -Force

& "$wd\certstrap.exe" init --common-name repCA --key rep.key --years 1000  --passphrase '""'
& "$wd\certstrap.exe" request-cert --ip $advertisedMachineIp --passphrase '""'
& "$wd\certstrap.exe" sign --years 1000  --CA repCA  --passphrase '""' $advertisedMachineIp

$repCACert = $hcfSettings.'REP_CA_CERT' + "`n" + (cat .\out\repCA.crt -Raw)
$repServerCert = cat .\out\$advertisedMachineIp.crt -Raw
$repServerKey = cat .\out\$advertisedMachineIp.key -Raw

rm -Force -Recurse .\out

## Note: All the hosts already come with HCP_SERVICE_DOMAIN_SUFFIX,
##       see 'properties.hcf.demophon.config' in the role manifest.

$env:DIEGO_INSTALL_DIR = "c:\diego"
$env:DIEGO_USER_PASSWORD = "changeme1234!"

$env:REP_CELL_ID = $advertisedMachineIp
$env:DIEGO_CELL_IP = $advertisedMachineIp
$env:STACKS = "win2012r2;windows2012R2"
$env:REP_ZONE = "windows"
$env:REP_MEMORY_MB = "auto"

$env:REP_REQUIRE_TLS = if ($hcfSettings.'SKIP_CERT_VERIFY_INTERNAL' -ieq "true") {'false'} else {'true'}
$env:REP_CA_CRT = $repCACert
$env:REP_SERVER_CRT = $repServerCert 
$env:REP_SERVER_KEY = $repServerKey

$env:CONSUL_SERVER_IP = $hcfSettings.'CONSUL_HOST'
$env:CONSUL_ENCRYPT_KEY = $hcfSettings.'CONSUL_ENCRYPTION_KEYS'
$env:CONSUL_CA_CRT = $hcfSettings.'CONSUL_CA_CERT'
$env:CONSUL_AGENT_CRT = $hcfSettings.'CONSUL_AGENT_CERT'
$env:CONSUL_AGENT_KEY = $hcfSettings.'CONSUL_AGENT_KEY'

$env:BBS_CA_CRT = $hcfSettings.'BBS_CA_CRT'
$env:BBS_CLIENT_CRT = $hcfSettings.'BBS_CLIENT_CRT'
$env:BBS_CLIENT_KEY = $hcfSettings.'BBS_CLIENT_KEY'
$env:BBS_ADDRESS = 'https://' + $hcfSettings.'DIEGO_DATABASE_HOST' + ':8889'

$etcdScheme = if ($hcfSettings.'SKIP_CERT_VERIFY_INTERNAL' -ieq "true") {'http://'} else {'https://'}
$env:ETCD_CLUSTER = $etcdScheme + $hcfSettings.'ETCD_HOST' + ':4001'
$env:ETCD_CA_CRT = $hcfSettings.'ETCD_CA_CRT'
$env:ETCD_CLIENT_CRT =  $hcfSettings.'ETCD_CLIENT_CRT'
$env:ETCD_CLIENT_KEY =  $hcfSettings.'ETCD_CLIENT_KEY'

$env:METRON_CA_CRT = $hcfSettings.'METRON_CA_CERT'
$env:METRON_CLIENT_CRT =  $hcfSettings.'METRON_CLIENT_CERT'
$env:METRON_CLIENT_KEY =  $hcfSettings.'METRON_CLIENT_KEY'

$env:LOGGRAGATOR_SHARED_SECRET = $hcfSettings.'LOGGREGATOR_SHARED_SECRET'
$env:LOGGREGATOR_JOB = $env:COMPUTERNAME
$env:LOGGRAGATOR_INDEX = [guid]::NewGuid().ToString()
$env:METRON_PROTOCOLS = "udp"


UninstallGardenWindows

echo "Installing Garden-Windows"
cmd /c  msiexec /passive /norestart /i $wd\GardenWindows.msi MACHINE_IP=$advertisedMachineIp


echo "Installing Diego-Windows"
cmd /c "$wd\diego-installer.exe /Q"

#Check if the services are started and running ok

function CheckService
{
	Param($serviceName)
	$rez = (get-service $serviceName -ErrorAction SilentlyContinue)

	if ($rez -ne $null) {
		if ($rez.Status.ToString().ToLower() -eq "running"){
			write-host "INFO: Service $serviceName is running"
		}else{
			write-warning "Service $serviceName is not running. Its status is $($rez.Status)"
		}

	}else{
		write-warning "Service $serviceName not found"
	}
}

#List of services to check if started
$services = @("rep","consul","metron","GardenWindowsService","ContainerizerService")

foreach ($service in $services){
	CheckService($service)
}

#Check is the services are in the correct state
try {
	$resp = (curl -UseBasicParsing http://127.0.0.1:8500 -ErrorAction:SilentlyContinue).StatusDescription
}catch{$resp="NOK"}
if ($resp -ne "OK"){
	$time=Get-Date
	Add-Content install.log "${time}: curl -UseBasicParsing http://127.0.0.1:8500 => $resp"
	write-warning "Consul service does not seem to be in the expected state!"
}else{
	echo "INFO: Consul service is in the expected state"
}

Start-Sleep -s 5

try{
	$resp = (curl -UseBasicParsing http://${advertisedMachineIp}:1800/ping).StatusDescription
}catch{$resp="NOK"}

if ($resp -ne "OK"){
	$time=Get-Date
	Add-Content install.log "${time}: curl -UseBasicParsing http://${advertisedMachineIp}:1800/ping => $resp"
	write-warning "Rep service does not seem to be in the expected state!"
}else{
	echo "INFO: Rep service is in the expected state"
}

echo ""
echo "Interrogating Rep status"
try{
  echo (curl -UseBasicParsing http://${advertisedMachineIp}:1800/state).Content | ConvertFrom-Json
}catch{
  write-warning "could not get Rep service status"
}
