Import-Module $PSScriptRoot\utils\utils.psm1

$serviceName = 'MSSQL$SQLEXPRESS'

if (-not (Get-Service "$serviceName" -ErrorAction SilentlyContinue)) {
  # Run the installer if the servie was not found
  RunProcessAsTask -FilePath "powershell" -Arguments " -ExecutionPolicy Bypass  -File $PSScriptRoot\install.ps1"
}

if (-not (Get-Service "$serviceName" -ErrorAction SilentlyContinue)) {
  echo "Service $serviceName not found."
  echo "Installation failed"
  exit 1
}

Start-Service $serviceName
echo "Service $serviceName started"

try {
  do {
    $serviceStatus = (Get-Service "$serviceName").Status
    if ($serviceStatus -eq "Stopped") {
        echo "Service $serviceName stopped"
        break;
    }

    sleep 5
  } while($true)
}
finally {
  $serviceStatus = (Get-Service "$serviceName").Status
  if ($serviceStatus -ne "Stopped") {
    echo "Stopping service $serviceName ..."
    Stop-Service $serviceName -Force
  }
}
