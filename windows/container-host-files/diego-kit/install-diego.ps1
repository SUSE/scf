Import-Module -DisableNameChecking "$PSScriptRoot\cf-install-utils.psm1"

## Create working directory

$wd="C:\diego-kit"
mkdir -f $wd
cd $wd


## Download installers
curl -UseBasicParsing -OutFile $wd\diego-installer.exe https://s3-us-west-1.amazonaws.com/clients.als.hpcloud.com/ro-artifacts/hcf-windows-release-artifacts/babysitter-24-2016-08-25_09-27-39/diego-installer.exe -Verbose

## Setup Vagrant HCF networking

$hcfCoreIpAddress = "192.168.77.77"
$advertisedMachineIp = (Find-NetRoute -RemoteIPAddress $hcfCoreIpAddress)[0].IPAddress
$advertisedMachineInterfaceIndex = (Find-NetRoute -RemoteIPAddress $hcfCoreIpAddress)[0].InterfaceIndex
$diegoInterface = Get-NetIPAddress -IPAddress $advertisedMachineIp

route delete 172.20.10.0
route add 172.20.10.0 mask 255.255.255.0 $hcfCoreIpAddress -p

## Make sure the IP is static (only necessary for vagrant + vmware)

$ipaddr = $diegoInterface.IPAddress
$maskbits = $diegoInterface.PrefixLength

$diegoInterface | Remove-NetIPAddress -AddressFamily IPv4 -Confirm:$false
$diegoInterface | New-NetIPAddress -AddressFamily IPv4  -IPAddress $ipaddr -PrefixLength $maskbits

## Setup Vagrant HCF DNS

$hcfServiceDiscoveryDns = @($hcfCoreIpAddress)

$currentDNS = ((Get-DnsClientServerAddress -InterfaceAlias $diegoInterface.InterfaceAlias) | where {$_.ServerAddresses -notmatch $hcfServiceDiscoveryDns } ).ServerAddresses
Set-DnsClientServerAddress -InterfaceAlias $diegoInterface.InterfaceAlias -ServerAddresses (($hcfServiceDiscoveryDns + $currentDNS) -join ",")

Set-DnsClientGlobalSetting -SuffixSearchList @("hcf")

SetInterfaceForLocalipGoPackage $advertisedMachineInterfaceIndex
DisableNegativeDnsClientCache

## Read HCF Settings

while(-not (Resolve-DnsName -DnsOnly "demophon-int" -ErrorAction SilentlyContinue)) {start-sleep 2; echo "Trying to resolve demophon-int hostname"} # Wait for HCF DNS-based service dicovery to work

$hcfSettings = GetConfigFromDemophon -Username "admin" -Password "changeme" -DemaphonEndpoint "https://demophon-int:8443" -SkipCertificateValidation $true

## Prepare diego configs parameters

$env:DIEGO_INSTALL_DIR = "c:\diego"
$env:DIEGO_USER_PASSWORD = "changeme1234!"

$env:REP_CELL_ID = $env:COMPUTERNAME
$env:DIEGO_CELL_IP = $ipaddr
$env:STACKS = "win2012r2;windows2012R2"
$env:REP_ZONE = "windows"
$env:REP_MEMORY_MB = "8192" # "auto"

$env:CONSUL_SERVER_IP = $hcfSettings.'CONSUL_HOST'
$env:CONSUL_ENCRYPT_KEY = $hcfSettings.'CONSUL_ENCRYPTION_KEYS'
$env:CONSUL_CA_CRT = $hcfSettings.'CONSUL_CA_CERT'
$env:CONSUL_AGENT_CRT = $hcfSettings.'CONSUL_AGENT_CERT'
$env:CONSUL_AGENT_KEY = $hcfSettings.'CONSUL_AGENT_KEY'

$env:BBS_CA_CRT = $hcfSettings.'BBS_CA_CRT'
$env:BBS_CLIENT_CRT = $hcfSettings.'BBS_CLIENT_CRT'
$env:BBS_CLIENT_KEY = $hcfSettings.'BBS_CLIENT_KEY'
$env:BBS_ADDRESS = 'https://' + $hcfSettings.'DIEGO_DATABASE_HOST' + ':8889'

$env:ETCD_CLUSTER = 'http://' + $hcfSettings.'ETCD_HOST' + ':4001'
$env:LOGGRAGATOR_SHARED_SECRET = $hcfSettings.'LOGGREGATOR_SHARED_SECRET'
$env:LOGGREGATOR_JOB = $env:COMPUTERNAME
$env:LOGGRAGATOR_INDEX = 0

echo "Installing Diego-Windows"
cmd /c "$wd\diego-installer.exe /Q"


## Checking health

echo "Checking Consul health"
echo (curl -UseBasicParsing http://127.0.0.1:8500/).StatusDescription

echo "Checking Rep health"
echo (curl -UseBasicParsing http://${advertisedMachineIp}:1800/ping).StatusDescription

echo "Interogating Rep status"
echo (curl -UseBasicParsing http://${advertisedMachineIp}:1800/state).Content | ConvertFrom-Json
