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

$wd="C:\diego-kit"
mkdir -f $wd
cd $wd


## Download installers

$gardenVersion = "v0.107"
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
echo (curl -UseBasicParsing http://127.0.0.1:1788/api/ping).Content

echo "Checking Garden health"
echo (curl -UseBasicParsing http://127.0.0.1:9241/ping).StatusCode

echo "Interogating Garden capacity endpoint"
echo (curl -UseBasicParsing http://127.0.0.1:9241/capacity).Content | ConvertFrom-Json
