$wd="C:\diego-kit"
mkdir -f $wd
cd $wd


## Download installers

curl -UseBasicParsing -OutFile $wd\setup.ps1 https://github.com/cloudfoundry/garden-windows-release/releases/download/v0.97/setup.ps1 -Verbose
curl -UseBasicParsing -OutFile $wd\DiegoWindows.msi https://github.com/cloudfoundry/diego-windows-release/releases/download/v0.166/DiegoWindows.msi -Verbose

# Download the latest version to have a proper external ip announced
curl -UseBasicParsing -OutFile $wd\GardenWindows.msi https://github.com/cloudfoundry/garden-windows-release/releases/download/v0.104/GardenWindows.msi -Verbose


## Setup diego networking

# 1.2.3.4 is used by rep to discover the IP address to be announced to the diego cluster
route add 1.2.3.4 192.168.77.77 -p
route add 172.20.10.0 mask 255.255.255.0 192.168.77.77 -p

$extraDNS = @("192.168.77.77")
$diegoInterface = ( Get-NetIPAddress -AddressFamily IPv4 | where {$_.IPAddress -match "192.168.77." } )
$currentDNS = ((Get-DnsClientServerAddress -InterfaceAlias $diegoInterface.InterfaceAlias) | where {$_.ServerAddresses -notmatch $extraDNS } ).ServerAddresses
Set-DnsClientServerAddress -InterfaceAlias $diegoInterface.InterfaceAlias -ServerAddresses (($extraDNS + $currentDNS) -join ",")


## Make sure the IP is static (only necessary for vagrant + vmware)

$ipaddr = $diegoInterface.IPAddress
$maskbits = $diegoInterface.PrefixLength

$diegoInterface | Remove-NetIPAddress -AddressFamily IPv4 -Confirm:$false
$diegoInterface | New-NetIPAddress -AddressFamily IPv4  -IPAddress $ipaddr -PrefixLength $maskbits


## Save diego configs parameters

$hcfCertsConfig="C:\hcf\bin\dev-certs.env"
$hcfSettings="C:\hcf\bin\dev-settings.env"

$diegoInterface.IPAddress | Out-File $wd\machine_ip

$file="$wd\bbs_ca.crt"
(cat $hcfCertsConfig | Select-String -Pattern ^BBS_CA_CRT=) -replace "BBS_CA_CRT=", ""-replace "\\n", "`n" > $file
(Get-Content $file) | foreach{ $_.Trim()} | Set-Content $file

$file="$wd\bbs_client.crt"
(cat $hcfCertsConfig | Select-String -Pattern ^BBS_CLIENT_CRT=) -replace "BBS_CLIENT_CRT=", ""-replace "\\n", "`n" > $file
(Get-Content $file) | foreach{ $_.Trim()} | Set-Content $file

$file="$wd\bbs_client.key"
(cat $hcfCertsConfig | Select-String -Pattern ^BBS_CLIENT_KEY=) -replace "BBS_CLIENT_KEY=", ""-replace "\\n", "`n" > $file
(Get-Content $file) | foreach{ $_.Trim()} | Set-Content $file

$mip = Get-Content $wd\machine_ip

echo "msiexec /passive /norestart /i $wd\GardenWindows.msi ADMIN_USERNAME=vagrant ADMIN_PASSWORD=vagrant MACHINE_IP=$mip EXTERNAL_IP=$mip" | Out-File -Encoding ascii $wd\install-garden.bat

# TODO: add this when the installer is patched  BBS_ADDRESS=https://diego-database.hcf:8889 ^
echo "msiexec /passive /norestart /i $wd\DiegoWindows.msi ^
  BBS_CA_FILE=$wd\bbs_ca.crt ^
  BBS_CLIENT_CERT_FILE=$wd\bbs_client.crt ^
  BBS_CLIENT_KEY_FILE=$wd\bbs_client.key ^
  CONSUL_IPS=consul.hcf ^
  CF_ETCD_CLUSTER=http://etcd.hcf:4001 ^
  STACK=windows2012R2 ^
  REDUNDANCY_ZONE=windows ^
  LOGGREGATOR_SHARED_SECRET=loggregator_endpoint_secret ^
  MACHINE_IP=$mip ^
  EXTERNAL_IP=$mip" `
 | Out-File -Encoding ascii $wd\install-diego.bat

powershell -NonInteractive $wd\setup.ps1
cmd /c "$wd\install-garden.bat"
cmd /c "$wd\install-diego.bat"


iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
choco install -f -y nssm

Set-Service RepService -StartupType Disabled
Stop-Service RepService

mkdir -f c:\diego-logs

nssm install rep "C:\Program Files\CloudFoundry\DiegoWindows\rep.exe" '-bbsAddress=https://diego-database.hcf:8889 -bbsCACert="""C:\Program Files\CloudFoundry\DiegoWindows\bbs_ca.crt""" -bbsClientCert="""C:\Program Files\CloudFoundry\DiegoWindows\bbs_client.crt""" -bbsClientKey="""C:\Program Files\CloudFoundry\DiegoWindows\bbs_client.key""" -consulCluster=http://127.0.0.1:8500 -debugAddr=0.0.0.0:17008 -listenAddr=0.0.0.0:1800 -preloadedRootFS=windows2012R2:/tmp/windows2012R2 -cellID=vagrant-2012-r2 -zone=windows -pollingInterval=30s -evacuationPollingInterval=10s -evacuationTimeout=600s -skipCertVerify=true -gardenNetwork=tcp -gardenAddr=127.0.0.1:9241 -memoryMB=auto -diskMB=auto -containerMaxCpuShares=1 -cachePath=C:\Windows\TEMP\executor\cache -maxCacheSizeInBytes=5000000000 -exportNetworkEnvVars=true -healthyMonitoringInterval=30s -unhealthyMonitoringInterval=0.5s -createWorkPoolSize=32 -deleteWorkPoolSize=32 -readWorkPoolSize=64 -metricsWorkPoolSize=8 -healthCheckWorkPoolSize=64 -tempDir=C:\Windows\TEMP\executor\tmp -logLevel=debug'
nssm set rep AppStdout c:\diego-logs\rep.log
nssm set rep AppStderr c:\diego-logs\rep.log
Start-Service rep
