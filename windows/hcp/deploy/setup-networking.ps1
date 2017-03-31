param(
	[Parameter(Mandatory=$true)]
	[ValidateScript({ if($_ -match "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"){
		$True
		}else{
			Throw "$_ is not a valid IPV4 address. Please use something like 10.21.0.1."
		}
	})]
    [string] $hcpMasterIP,

	[Parameter(Mandatory=$true)]
	[ValidateScript({If (Test-Path $_) {
			$True
		}else{
			Throw "$_ is not a valid file."
		}
	})]
    [string] $hcpKeypairFile,

	[Parameter(Mandatory=$false)]
    [string] $hcpMasterSshUser = "ubuntu",

    [Parameter(Mandatory=$false)]
    [string] $flannelUserPassword,

    [Parameter(Mandatory=$false)]
	[ValidateScript({If (Test-Path $_) {
			$True
		}else{
			Throw "$_ is not a valid file."
		}
	})]
    [string] $flannelInstallDir = "C:/flannel",

    [Parameter(Mandatory=$false)]
    [ValidateScript({ if($_ -match "^[0-9]{1,3}[s,m]$"){
		$True
		}else{
			Throw "$_ is not a valid interval. Please use something like 1s for 1 second or 2m for 2 minutes."
		}
	})]
    [string] $kubeQueryPeriod = "1s",

    [Parameter(Mandatory=$false)]
	[ValidateScript({ if($_ -match "^http:\/\/[0-9A-Za-z-_\.]*:[0-9]{2,5}$"){
		$True
		}else{
			Throw "$_ is not a valid address:port for proxy. Please use something like http://10.12.22.1:3128 or don't use this param to use the default."
		}
	})]
    [string] $httpProxy = "",
	[Parameter(Mandatory=$false)]
	[ValidateScript({ if($_ -match "^http[s]?:\/\/[0-9A-Za-z-_\.]*:[0-9]{2,5}$"){
		$True
		}else{
			Throw "$_ is not a valid address:port for proxy. Please use something like http://10.12.22.1:3128 or http://host.com:8080 or don't use this param to use the default."
		}
	})]
    [string] $httpsProxy = "",
	[Parameter(Mandatory=$false)]
	[ValidateScript( { If ($_ -match "^((([0-9|\*]{1,3}\.[0-9|\*]{1,3}\.[0-9|\*]{1,3}\.[0-9|\*]{1,3})|([a-zA-Z0-9-*_\.]{3,}))\,?){1,}$"){
		$True
		}else{
			Throw "$_ is not a valid specifier for noProxy. Please use something like 10.21.*.*,192.100.200.* or don't use this param to use the default."
		}
	})]
    [string] $noProxy = ""
)

if ($flannelUserPassword -eq "") {
    Write-Output "Flannel windows user password was not supplied. Generating a random password ..."
    [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
    $flannelUserPassword = [System.Web.Security.Membership]::GeneratePassword(12,1)
}

$ErrorActionPreference = "Stop"

$wd="$PSScriptRoot\resources\hcf-networking"
mkdir -f $wd  | Out-Null

$certsDir = "C:\hcf-certs"
mkdir -f $certsDir | Out-Null

$etcdKeyFile = Join-Path $certsDir "flannel_client.key"
$etcdCertFile = Join-Path $certsDir "flannel_client.cert"
$etcdCaFile = Join-Path $certsDir "flannel_ca.crt"
$kubeKeyFile = Join-Path $certsDir "kube_client.key"
$kubeCertFile = Join-Path $certsDir "kube_client.cert"
$kubeCaFile = Join-Path $certsDir "kube_ca.crt"

if (!(Test-Path "$($env:USERPROFILE)\Documents\WindowsPowerShell\Modules\Posh-SSH")) {
    $targetondisk = "$($env:USERPROFILE)\Documents\WindowsPowerShell\Modules"
    mkdir -f $targetondisk | out-null
    $shell_app=new-object -com shell.application
    $poshSshZip= Join-Path $wd Posh-SSH.zip
    $zip_file = $shell_app.namespace($poshSshZip)
    Write-Output "Uncompressing $($poshSshZip) to $($targetondisk)"
    $destination = $shell_app.namespace($targetondisk)
    $destination.Copyhere($zip_file.items(), 0x10)
    $poshSshDir = (Get-ChildItem ($targetondisk+"\Posh-SSH-*"))[0].FullName
    Write-Output "Renaming folder $($poshSshDir) to Posh-SSH"
    Rename-Item -Path $poshSshDir -NewName "Posh-SSH" -Force
    Write-Output "Module Posh-SSH has been installed"
}

Import-Module -Name posh-ssh

$cred = New-Object System.Management.Automation.PSCredential ($hcpMasterSshUser, (new-object System.Security.SecureString))
$sshSessionId = (New-SSHSession -ComputerName $hcpMasterIP -KeyFile $hcpKeypairFile -Force  -Verbose -Credential $cred).SessionId

(Invoke-SSHCommand -Command "cat /etc/flannel/ca.crt" -SessionId $sshSessionId).Output | Out-File $etcdCaFile -Encoding ascii
(Invoke-SSHCommand -Command "cat /etc/flannel/client.key" -SessionId $sshSessionId).Output | Out-File $etcdKeyFile -Encoding ascii
(Invoke-SSHCommand -Command "cat /etc/flannel/client.cert" -SessionId $sshSessionId).Output | Out-File $etcdCertFile -Encoding ascii

(Invoke-SSHCommand -Command "cat /srv/kubernetes/ca.crt" -SessionId $sshSessionId).Output | Out-File $kubeCaFile -Encoding ascii
(Invoke-SSHCommand -Command "cat /srv/kubernetes/kubernetes.key" -SessionId $sshSessionId).Output | Out-File $kubeKeyFile -Encoding ascii
(Invoke-SSHCommand -Command "cat /srv/kubernetes/kubernetes.cert" -SessionId $sshSessionId).Output | Out-File $kubeCertFile -Encoding ascii

$kubeApiServer = (Invoke-SSHCommand -Command "cat /etc/default/kube-apiserver" -SessionId $sshSessionId).Output
$kubeBindAddress = [regex]::Match($kubeApiServer, '--bind-address\s(\S+)\s').captures.groups[1].value
$kubeSecurePort = [regex]::Match($kubeApiServer, '--secure-port\s(\S+)\s').captures.groups[1].value
$kubeServSubnet = [regex]::Match($kubeApiServer, '--service-cluster-ip-range=(\S+)\s').captures.groups[1].value
$etcdPort = [regex]::Match($kubeApiServer, '--etcd_servers=https:\S+:(\d+)\s').captures.groups[1].value

$kubeNetInterface = (Invoke-SSHCommand -Command "ifconfig | grep -B1 `"inet addr:${kubeBindAddress}`" | awk '`$1!=`"inet`" && `$1!=`"--`" {print `$1}'" -SessionId $sshSessionId).Output
$kubeAllowedSubnet = (Invoke-SSHCommand -Command "ip -o -f inet addr show | grep ${kubeNetInterface} | awk '{print `$4}'" -SessionId $sshSessionId).Output

if (($httpProxy -ne "") -and ($httpsProxy -ne "")) {

    $httpProxy = (Invoke-SSHCommand -Command "echo `$HTTP_PROXY" -SessionId $sshSessionId).Output
    $httpsProxy = (Invoke-SSHCommand -Command "echo `$HTTPS_PROXY" -SessionId $sshSessionId).Output
    $noProxy = (Invoke-SSHCommand -Command "echo `$NO_PROXY" -SessionId $sshSessionId).Output

    $hklm64 = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
    $hklm32 = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32)

    ## Disable IE first run wizard
    ## https://www.petri.com/disable-ie8-ie9-welcome-screen
    $ieMainRegPath = "Software\Policies\Microsoft\Internet Explorer\Main"
    $disableWizard = { param ($ieRegKey)
        $ieMainSettings = $ieRegKey.CreateSubKey($ieMainRegPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree)
        $ieMainSettings.SetValue("DisableFirstRunCustomize", 1)
        $ieMainSettings.Dispose()
    }

    & $disableWizard $hklm64
    & $disableWizard $hklm32


    ## Parse proxy env

    $proxyServers = ""

    if ($httpProxy -ne "") {
        $proxyServers += "http=$httpProxy"
    }

    if ($httpsProxy -ne "") {
        if ($proxyServers -ne "") { $proxyServers += ";" }
        $proxyServers += "https=$httpsProxy"
    }

    # TODO improve bypass list

    $bypassList = @()
    foreach ($bp in $noProxy) {
        if ($bp.EndsWith("/16")) {
            $splits = $bp.Split('.')
            $bypassList += "$($splits[0]).$($splits[1]).*.*"
        }
        else {
            $bypassList += $bp
        }
    }

    if (!($bypassList -contains "demophon")){
        $bypassList += "demophon"
    }

    $proxyOverride = $bypassList -join ";"

    echo "Setting proxy servers     : $proxyServers"
    echo "Setting proxy bypass list : $proxyOverride"


    # Disable ProxySettingsPerUser
    $proxyPolicyRegPath = "Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
    $setProxyPolicy = { param ($ieRegKey)
        $iePolicySettings = $ieRegKey.CreateSubKey($proxyPolicyRegPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree)
        $iePolicySettings.SetValue("ProxySettingsPerUser", 0)
        $iePolicySettings.Dispose()
    }

    & $setProxyPolicy $hklm64
    & $setProxyPolicy $hklm32

    # Set proxy for WinINET at machine level
    $proxyRegPath = "Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $setProxy = { param ($ieRegKey)
        $ieSettings = $ieRegKey.CreateSubKey($proxyRegPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree)
        $ieSettings.SetValue("AutoDetect", 0)
        $ieSettings.SetValue("ProxyEnable", 1)
        $ieSettings.SetValue("MigrateProxy", 0)
        $ieSettings.SetValue("ProxyServer", $proxyServers, [Microsoft.Win32.RegistryValueKind]::String)
        $ieSettings.SetValue("ProxyOverride", $proxyOverride)
        $ieSettings.Dispose()
    }

    & $setProxy $hklm64
    & $setProxy $hklm32

    $hklm64.Dispose()
    $hklm32.Dispose()

    # Set proxy for WinHTTP
    netsh winhttp set proxy proxy-server="$proxyServers" bypass-list="$proxyOverride"

    # Run Internet Explorer with an interactive logon token to
    # initialize the system proxy.
    # I agree, it is weird, but it is the only workaround that does not require
    # the user to RDP into the box and initialize IE.
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "powershell.exe"
    $startInfo.Arguments = "/c", "(new-object -ComObject internetexplorer.application).navigate('127.0.0.1')"
    $startInfo.RedirectStandardOutput = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $false
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $process.Start()
    $process.WaitForExit()
}

Write-Output "Getting local IP ..."
$localIP = (Find-NetRoute -RemoteIPAddress $hcpMasterIP)[0].IPAddress
Write-Output "Found local IP: ${localIP}"

if($kubeServSubnet -eq ""){
  $kubeServSubnet="172.16.0.0/16"
}

$env:WIN_KUBE_SERV_SUBNET = $kubeServSubnet
$env:WIN_KUBE_API = "https://${kubeBindAddress}:${kubeSecurePort}"
$env:WIN_KUBE_QUERY_PERIOD = $kubeQueryPeriod
$env:WIN_KUBE_EXTERNAL_IP = $localIP
$env:WIN_KUBE_CA_FILE = $kubeCaFile
$env:WIN_KUBE_CERT_FILE = $kubeCertFile
$env:WIN_KUBE_KEY_FILE = $kubeKeyFile

if($kubeAllowedSubnet -ne ""){
  $env:WIN_kube_ALLOWED_SUBNET = $kubeAllowedSubnet
}

Write-Output @"
Installing win-kube-connector using:
    WIN_KUBE_SERV_SUBNET=$($env:WIN_KUBE_SERV_SUBNET)
    WIN_KUBE_API=$($env:WIN_KUBE_API)
    WIN_KUBE_QUERY_PERIOD=$($env:WIN_KUBE_QUERY_PERIOD)
    WIN_KUBE_EXTERNAL_IP=$($env:WIN_KUBE_EXTERNAL_IP)
    WIN_KUBE_CA_FILE=$($env:WIN_KUBE_CA_FILE)
    WIN_KUBE_CERT_FILE=$($env:WIN_KUBE_CERT_FILE)
    WIN_KUBE_KEY_FILE=$($env:WIN_KUBE_KEY_FILE)
"@
if($kubeAllowedSubnet -ne ""){
  Write-Output "    WIN_KUBE_ALLOWED_SUBNET=$($env:WIN_KUBE_ALLOWED_SUBNET)"
}
cmd /c "$wd\win-kube-conn-installer.exe /Q"
Write-Output "Finished installing win-kube-connector."

$env:FLANNEL_ETCD_ENDPOINTS = "https://${hcpMasterIP}:${etcdPort}"
$env:FLANNEL_INSTALL_DIR = $flannelInstallDir
$env:FLANNEL_USER_PASSWORD = $flannelUserPassword
$env:FLANNEL_EXT_INTERFACE = $localIP
$env:FLANNEL_ETCD_KEYFILE = $etcdKeyfile
$env:FLANNEL_ETCD_CERTFILE = $etcdCertFile
$env:FLANNEL_ETCD_CAFILE = $etcdCaFile

net user flannel /delete /y

Write-Output @"
Installing flannel using:
    FLANNEL_ETCD_ENDPOINTS=$($env:FLANNEL_ETCD_ENDPOINTS)
    FLANNEL_INSTALL_DIR=$($env:FLANNEL_INSTALL_DIR)
    FLANNEL_USER_PASSWORD=$($env:FLANNEL_USER_PASSWORD)
    FLANNEL_EXT_INTERFACE=$($env:FLANNEL_EXT_INTERFACE)
    FLANNEL_ETCD_KEYFILE=$($env:FLANNEL_ETCD_KEYFILE)
    FLANNEL_ETCD_CERTFILE=$($env:FLANNEL_ETCD_CERTFILE)
    FLANNEL_ETCD_CAFILE=$($env:FLANNEL_ETCD_CAFILE)
"@
cmd /c "$wd\flannel-installer.exe /Q"
Write-Output "Finished installing flannel"

Write-Output "Getting dns server ..."
#TODO retrieve insecure kube address
$kubedns = (Invoke-SSHCommand -Command "curl 127.0.0.1:8080/api/v1/namespaces/kube-system/services/kube-dns" -SessionId $sshSessionId).Output -join " " | ConvertFrom-Json
$dns = $kubedns.spec.ClusterIP
Write-Output "Found dns ${dns}"
Write-Output "Setting dns server..."
Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses ($dns)
Write-Output "Finished setting dns server"

Write-Output "Waiting for services to start ..."
Start-Sleep -s 30

#Check if the services are started and running ok

function CheckService
{
	Param($serviceName)
	$rez = (get-service $serviceName -ErrorAction SilentlyContinue)

	if ($rez -ne $null) {
		if ($rez.Status.ToString().ToLower() -eq "running"){
			write-host "INFO: Service $serviceName is running"
		}else{
			write-warning "Service $serviceName is not running. Its status is $($rez.Status.ToString())"
      Write-Output "Please look in the logs C:\$serviceName\logs for a possible reason."
		}

	}else{
		write-warning "Service $serviceName not found"
	}
}

#List of services to check if started
$services = @("win-kube-connector","flannel")

foreach ($service in $services){
	CheckService($service)
}

#TODO retrieve insecure kube address
Write-Output "Getting rpmgr IP ..."
$rpmgr = (Invoke-SSHCommand -Command "curl 127.0.0.1:8080/api/v1/namespaces/hcp/services/rpmgr-int" -SessionId $sshSessionId).Output -join " " | ConvertFrom-Json
$rpmgrip = $rpmgr.spec.ClusterIP
Write-Output "Found rpmgr IP: ${rpmgrip}"

Remove-SSHSession $sshSessionId

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

