$wd="C:\diego-kit"
mkdir -f $wd
cd $wd


## Download installers
curl -UseBasicParsing -OutFile $wd\diego-installer.exe https://s3-us-west-1.amazonaws.com/clients.als.hpcloud.com/ro-artifacts/hcf-windows-release-artifacts/babysitter-13-2016-04-28_12-19-17/diego-installer.exe -Verbose

## Setup diego networking

# 1.2.3.4 is used by rep to discover the IP address to be announced to the diego cluster
route delete 1.2.3.4
route add 1.2.3.4 192.168.77.77 -p

route delete 172.20.10.0
route add 172.20.10.0 mask 255.255.255.0 192.168.77.77 -p

$hcfServiceDiscoveryDns = @("192.168.77.77")

$machineIp = (Find-NetRoute -RemoteIPAddress "192.168.77.77")[0].IPAddress
$diegoInterface = Get-NetIPAddress -IPAddress $machineIp

$currentDNS = ((Get-DnsClientServerAddress -InterfaceAlias $diegoInterface.InterfaceAlias) | where {$_.ServerAddresses -notmatch $hcfServiceDiscoveryDns } ).ServerAddresses
Set-DnsClientServerAddress -InterfaceAlias $diegoInterface.InterfaceAlias -ServerAddresses (($hcfServiceDiscoveryDns + $currentDNS) -join ",")

Set-DnsClientGlobalSetting -SuffixSearchList @("hcf")

## Disable negative DNS client cache

New-Item 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -Force | `
  New-ItemProperty -Name MaxNegativeCacheTtl -PropertyType "DWord" -Value 1 -Force

Clear-DnsClientCache


## Make sure the IP is static (only necessary for vagrant + vmware)

$ipaddr = $diegoInterface.IPAddress
$maskbits = $diegoInterface.PrefixLength

$diegoInterface | Remove-NetIPAddress -AddressFamily IPv4 -Confirm:$false
$diegoInterface | New-NetIPAddress -AddressFamily IPv4  -IPAddress $ipaddr -PrefixLength $maskbits


## Read HCF Settings

$hcfSettings = New-Object System.Collections.Hashtable
$hcfCertsConfig = New-Object System.Collections.Hashtable
(cat "C:\hcf\bin\dev-settings.env") -split '`n' |  % { $s = $_ -split ('=', 2); $hcfSettings.Add( $s[0], $s[1] ) }
(cat "C:\hcf\bin\dev-certs.env") -split '`n' | % { $s = $_ -split ('=', 2); $hcfCertsConfig.Add( $s[0], $s[1] -replace ( "\\n", "`n") ) }


## Prepare diego configs parameters

$env:DIEGO_INSTALL_DIR = "c:\diego"
$env:DIEGO_USER_PASSWORD = "changeme1234!"

$env:REP_CELL_ID = $env:COMPUTERNAME
$env:DIEGO_CELL_IP = $ipaddr
$env:DIEGO_NETADAPTER = $diegoInterface.InterfaceAlias
$env:STACKS = "win2012r2;windows2012R2"
$env:REP_ZONE = "windows"
$env:REP_MEMORY_MB = "8192" # "auto"

$env:CONSUL_SERVER_IP = $hcfSettings.'CONSUL_HOST'
$env:CONSUL_ENCRYPT_KEY = $hcfSettings.'CONSUL_ENCRYPTION_KEYS'
$env:CONSUL_CA_CRT = $hcfCertsConfig.'CONSUL_CA_CERT'
$env:CONSUL_AGENT_CRT = $hcfCertsConfig.'CONSUL_AGENT_CERT'
$env:CONSUL_AGENT_KEY = $hcfCertsConfig.'CONSUL_AGENT_KEY'

$env:BBS_CA_CRT = $hcfCertsConfig.'BBS_CA_CRT'
$env:BBS_CLIENT_CRT = $hcfCertsConfig.'BBS_CLIENT_CRT'
$env:BBS_CLIENT_KEY = $hcfCertsConfig.'BBS_CLIENT_KEY'
$env:BBS_ADDRESS = 'https://' + $hcfSettings.'DIEGO_DATABASE_HOST' + ':8889'

$env:ETCD_CLUSTER = 'http://' + $hcfSettings.'ETCD_HOST' + ':4001'
$env:LOGGRAGATOR_SHARED_SECRET = $hcfSettings.'LOGGREGATOR_SHARED_SECRET'
$env:LOGGREGATOR_JOB = $env:COMPUTERNAME
$env:LOGGRAGATOR_INDEX = 0

echo "Installing Diego-Windows"
cmd /c "$wd\diego-installer.exe /Q"

echo "Checking Consul health"
echo (curl -UseBasicParsing http://127.0.0.1:8500/).StatusDescription

echo "Checking Rep health"
echo (curl -UseBasicParsing http://127.0.0.1:1800/ping).StatusDescription

echo "Interogating Rep status"
echo (curl -UseBasicParsing http://127.0.0.1:1800/state).Content | ConvertFrom-Json
