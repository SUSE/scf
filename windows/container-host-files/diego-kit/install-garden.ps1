Import-Module -DisableNameChecking "$PSScriptRoot\cf-install-utils.psm1"

## Create working directory

$wd="C:\garden-kit"
mkdir -f $wd
cd $wd


## Download dependencies

echo "Downloading localwall"
curl -Verbose -UseBasicParsing -OutFile $wd\localwall.exe https://s3-us-west-1.amazonaws.com/clients.als.hpcloud.com/ro-artifacts/als-win-localhost-filter-artifacts/babysitter-23-2016-07-13_10-01-51/localwall.exe

# VC redist are used by cf-iis8-buildpack
echo "Downloading VC 2013 and 2015 redistributable"
mkdir -Force "$wd\vc2013", "$wd\vc2015"
curl -Verbose -UseBasicParsing  -OutFile "vc2013\vcredist_x86.exe"  https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe
curl -Verbose -UseBasicParsing  -OutFile "vc2013\vcredist_x64.exe"  https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe
curl -Verbose -UseBasicParsing  -OutFile "vc2015\vc_redist.x86.exe"  https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x86.exe
curl -Verbose -UseBasicParsing  -OutFile "vc2015\vc_redist.x64.exe"  https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe

$gardenVersion = "v0.153"
echo "Downloading GardenWindows.msi $gardenVersion"
curl  -UseBasicParsing  -Verbose  -OutFile $wd\GardenWindows.msi  https://github.com/cloudfoundry/garden-windows-release/releases/download/$gardenVersion/GardenWindows.msi


## Install dependencies

echo "Installing VC 2013 and 2015 redistributable"
start -Wait "vc2013\vcredist_x86.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "vc2013\vcredist_x64.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "vc2015\vc_redist.x86.exe"  -ArgumentList "/install /passive /norestart"
start -Wait "vc2015\vc_redist.x64.exe"  -ArgumentList "/install /passive /norestart"

IntalledRequiredWindowsFeatures

EnableDiskQuota
ConfigureCellWindowsFirewall
ConfigureCellLocalwall "$wd\localwall.exe"


## Prepare configs

$hcfCoreIpAddress = "192.168.77.77"
$advertisedMachineIp = (Find-NetRoute -RemoteIPAddress $hcfCoreIpAddress)[0].IPAddress
echo "The machine IP dicovered that will be used for Diego and CloudFoundry is: $advertisedMachineIp"


## Install the msi

UninstallGardenWindows

echo "Installing Garden-Windows"
cmd /c  msiexec /passive /norestart /i $wd\GardenWindows.msi MACHINE_IP=$advertisedMachineIp


## Checking health

echo "Checking Containerizer health"
echo (curl -UseBasicParsing http://127.0.0.1:1788/api/ping).StatusDescription

echo "Checking Garden health"
echo (curl -UseBasicParsing http://127.0.0.1:9241/ping).StatusDescription

echo "Interogating Garden capacity endpoint"
echo (curl -UseBasicParsing http://127.0.0.1:9241/capacity).Content | ConvertFrom-Json
