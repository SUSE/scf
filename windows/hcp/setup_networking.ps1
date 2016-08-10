param (
    [Parameter(Mandatory=$true)]
    [string] $k8MasterIP,
	[Parameter(Mandatory=$true)]
    [string] $k8sServSubnet,
	[Parameter(Mandatory=$false)]
    [int] $k8sPort = 8080,
	[Parameter(Mandatory=$false)]
    [int] $etcdPort = 2379,
	[Parameter(Mandatory=$false)]
    [string] $flannelUserPassword = "Password1234!",
	[Parameter(Mandatory=$false)]
    [string] $flannelInstallDir = "C:/flannel",
	[Parameter(Mandatory=$false)]
    [string] $k8sQueryPeriod = "1s"
)

Write-Output "Creating working directory ..."
$wd="C:\hcf-networking"
mkdir -f $wd  | Out-Null
cd $wd

Write-Output "Getting local IP ..."
$localIP = (Find-NetRoute -RemoteIPAddress $k8MasterIP)[0].IPAddress
Write-Output "Found local IP: ${localIP}"

Write-Output "Downloading win-k8s-connector installer ..."
curl -UseBasicParsing -OutFile $wd\win-k8s-conn-installer.exe https://s3-us-west-1.amazonaws.com/clients.als.hpcloud.com/ro-artifacts/win-k8s-connector/10-2016-08-05_13-38-07/win-k8s-conn-installer.EXE -Verbose
Write-Output "Finished downloading win-k8s-connector installer."

$env:WIN_K8S_SERV_SUBNET = $k8sServSubnet
$env:WIN_K8S_IP = "${k8MasterIP}:${k8sPort}"
$env:WIN_K8S_QUERY_PERIOD = $k8sQueryPeriod
$env:WIN_K8S_EXTERNAL_IP = $localIP

Write-Output @"
Installing win-k8s-connector using: 
    WIN_K8S_SERV_SUBNET=$($env:WIN_K8S_SERV_SUBNET)
    WIN_K8S_IP=$($env:WIN_K8S_IP)
    WIN_K8S_QUERY_PERIOD=$($env:WIN_K8S_QUERY_PERIOD)
    WIN_K8S_EXTERNAL_IP=$($env:WIN_K8S_EXTERNAL_IP)
"@
cmd /c "$wd\win-k8s-conn-installer.exe /Q"
Write-Output "Finished installing win-k8s-connector."

Write-Output "Downloading flannel installer ..."
curl -UseBasicParsing -OutFile $wd\flannel-installer.exe https://s3-us-west-1.amazonaws.com/clients.als.hpcloud.com/ro-artifacts/flannel/5-2016-08-09_10-25-30/flannel-installer.EXE -Verbose
Write-Output "Finished downloading flannel installer."

$env:FLANNEL_ETCD_ENDPOINTS = "http://${k8MasterIP}:${etcdPort}"
$env:FLANNEL_INSTALL_DIR = $flannelInstallDir
$env:FLANNEL_USER_PASSWORD = $flannelUserPassword
$env:FLANNEL_EXT_INTERFACE = $localIP

Write-Output @"
Installing flannel using: 
    FLANNEL_ETCD_ENDPOINTS=$($env:FLANNEL_ETCD_ENDPOINTS)
    FLANNEL_INSTALL_DIR=$($env:FLANNEL_INSTALL_DIR)
    FLANNEL_USER_PASSWORD=$($env:FLANNEL_USER_PASSWORD)
    FLANNEL_EXT_INTERFACE=$($env:FLANNEL_EXT_INTERFACE)
"@
cmd /c "$wd\flannel-installer.exe /Q"
Write-Output "Finished installing flannel"

Write-Output "Getting dns server ..."
$kubedns = (curl "${k8MasterIP}:${k8sPort}/api/v1/namespaces/kube-system/services/kube-dns").Content | ConvertFrom-Json
$dns = $kubedns.spec.ClusterIP
Write-Output "Found dns ${dns}"
Write-Output "Setting dns server..."
$networkIntefaceIndex = (Get-NetIPAddress -IPAddress $localIP).InterfaceIndex
Set-DnsClientServerAddress -InterfaceIndex $networkIntefaceIndex -ServerAddresses ($dns)
Write-Output "Finished setting dns server"

Write-Output "Waiting for services to start ..."
Start-Sleep -s 30

Write-Output "Getting rpmgr IP ..."
$rpmgr = (curl "${k8MasterIP}:${k8sPort}/api/v1/namespaces/hcp/services/rpmgr-int").Content | ConvertFrom-Json
$rpmgrip = $rpmgr.spec.ClusterIP
Write-Output "Found rpmgr IP: ${rpmgrip}"

Write-Output "Checking route ..."
$netroute = (Find-NetRoute -RemoteIPAddress $rpmgrip).DestinationPrefix
if ($netroute -ne "0.0.0.0/0") {
    Write-Host "Found route ${netroute}"
}
else {
    Write-Error "Could not find route"
    exit 1
}

Write-Output "Checking dns ..."
Resolve-DnsName "nats-int.hcp.svc.cluster.hcp"
Write-Output "Finished."