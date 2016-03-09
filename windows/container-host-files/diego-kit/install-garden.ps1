## Utilities

# Source: https://blogs.technet.microsoft.com/heyscriptingguy/2013/06/03/generating-a-new-password-with-windows-powershell/
Function Get-TempPassword() {
    Param([int]$length=40)

    $charSet=$NULL;
    For ($a=48;$a -le 90;$a++) {$charSet+=,[char][byte]$a }

    For ($loop=1; $loop -le $length; $loop++) {
        $TempPassword+=($charSet | Get-Random)
    }
    return $TempPassword
}


## Create working directory

$wd="C:\garden-kit"
mkdir -f $wd
cd $wd


## Download and install global dependencies

# VC redist are used by cf-iis8-buildpack
echo "Downloading VC 2013 and 2015 Update 1 redistributable"
mkdir -Force "$wd\vc2013", "$wd\vc2015u1"
curl -Verbose -UseBasicParsing  -OutFile "vc2013\vcredist_x86.exe"  http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe
curl -Verbose -UseBasicParsing  -OutFile "vc2013\vcredist_x64.exe"  http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe
curl -Verbose -UseBasicParsing  -OutFile "vc2015u1\VC_redist.x86.exe"  https://download.microsoft.com/download/C/E/5/CE514EAE-78A8-4381-86E8-29108D78DBD4/VC_redist.x86.exe
curl -Verbose -UseBasicParsing  -OutFile "vc2015u1\VC_redist.x64.exe"  https://download.microsoft.com/download/C/E/5/CE514EAE-78A8-4381-86E8-29108D78DBD4/VC_redist.x64.exe

echo "Installing VC 2013 and 2015 Update 1 redistributable"
start -Wait "vc2013\vcredist_x86.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "vc2013\vcredist_x64.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "vc2015u1\VC_redist.x86.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "vc2015u1\VC_redist.x64.exe"  -ArgumentList "/install /passive /norestart"

echo "Installing Windows Features"
Install-WindowsFeature  Web-Webserver, Web-WebSockets, AS-Web-Support, AS-NET-Framework, Web-WHC, Web-ASP
Install-WindowsFeature  Web-Net-Ext, Web-AppInit # Extra features for the cf-iis8-buildpack


## Download installers

$gardenVersion = "v0.116"
echo "Downloading GardenWindows.msi $gardenVersion"
curl  -UseBasicParsing  -Verbose  -OutFile $wd\GardenWindows.msi  https://github.com/cloudfoundry/garden-windows-release/releases/download/$gardenVersion/GardenWindows.msi

echo "Downloading GardenWindows setup.ps1 $gardenVersion"
curl  -UseBasicParsing -Verbose  -OutFile $wd\setup.ps1  https://github.com/cloudfoundry/garden-windows-release/releases/download/$gardenVersion/setup.ps1


## Prepare configs

$externalRoute = "192.168.77.77"
$machineIp = (Find-NetRoute -RemoteIPAddress $externalRoute)[0].IPAddress
echo "The machine IP dicovered that will be used for Diego and CloudFoundry is: $machineIp"


$gardenProduct = gwmi win32_product | ? {$_.name -match 'GardenWindows'}
if ($gardenProduct) {
  echo "Uninstalling existing GardenWindows. `nDetails: $gardenProduct"
  $gardenProduct.Uninstall()
}

$gardenUsername = "GardenAdmin"
$gardenUserPassword = "Aa1!" + (Get-TempPassword)
echo "Creating local user $gardenUsername"
net user "$gardenUsername" /delete /yes
net user "$gardenUsername" "$gardenUserPassword" /add /yes
net localgroup "Administrators" "$gardenUsername" /add /yes


echo "msiexec /passive /norestart /i $wd\GardenWindows.msi ^
  ADMIN_USERNAME=`"$gardenUsername`" ^
  ADMIN_PASSWORD=`"$gardenUserPassword`" ^
  MACHINE_IP=$machineIp" `
 | Out-File -Encoding ascii  $wd\install-garden.bat


## Install the msi

echo "Running GardenWindows setup.ps1"
powershell -NonInteractive $wd\setup.ps1

echo "Installing GardenWindows"
cmd /c "$wd\install-garden.bat"


## Checking health

echo "Checking Containerizer health"
echo (curl -UseBasicParsing http://127.0.0.1:1788/api/ping).StatusDescription

echo "Checking Garden health"
echo (curl -UseBasicParsing http://127.0.0.1:9241/ping).StatusDescription

echo "Interogating Garden capacity endpoint"
echo (curl -UseBasicParsing http://127.0.0.1:9241/capacity).Content | ConvertFrom-Json
