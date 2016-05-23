Import-Module $PSScriptRoot\utils\utils.psm1

$serviceNames = "ContainerizerService", "GardenWindowsService", "consul", "metron", "rep"

if (-not (Get-Service $serviceNames -ErrorAction SilentlyContinue -ErrorVariable err) -or $err) {
  # Run the installer if the servie was not found
  RunProcessAsTask -FilePath "powershell" -Arguments " -ExecutionPolicy Bypass  -File $PSScriptRoot\install.ps1"
}

if (-not (Get-Service $serviceNames -ErrorAction SilentlyContinue -ErrorVariable err) -or $err) {
  echo "Service $serviceNames not found.", $err
  echo "Installation failed"
  exit 1
}

Start-Service $serviceNames
echo ("Services " + ($serviceNames -join ', ') + " started")

try {
  do {
    $stoppedServices = (Get-Service $serviceNames).Where{$_.Status -eq "Stopped"}
    if ($stoppedServices) {
        echo "Service $stoppedServices stopped"
        break;
    }

    sleep 5
  } while($true)
}
finally {
  echo "Stopping all services: $serviceNames"
  Stop-Service $serviceNames -Force
}
