## Setup Vagrant HCF networking

$coreIpAddress = "192.168.77.77"

# 1.2.3.4 is used by rep and metron to discover the IP address to be announced to the diego cluster
# https://github.com/pivotal-golang/localip/blob/ca5f12419a47fe0c8547eea32f9498eb6e9fe817/localip.go#L7
route delete 1.2.3.4
route add 1.2.3.4 $coreIpAddress -p

route delete 172.20.10.0
route add 172.20.10.0 mask 255.255.255.0 $coreIpAddress -p

$hcfServiceDiscoveryDns = @($coreIpAddress)

$machineIp = (Find-NetRoute -RemoteIPAddress $coreIpAddress)[0].IPAddress
$diegoInterface = Get-NetIPAddress -IPAddress $machineIp

$currentDNS = ((Get-DnsClientServerAddress -InterfaceAlias $diegoInterface.InterfaceAlias) | where {$_.ServerAddresses -notmatch $hcfServiceDiscoveryDns } ).ServerAddresses
Set-DnsClientServerAddress -InterfaceAlias $diegoInterface.InterfaceAlias -ServerAddresses (($hcfServiceDiscoveryDns + $currentDNS) -join ",")

Set-DnsClientGlobalSetting -SuffixSearchList @("hcf")
