$serviceName = 'MSSQL$SQLEXPRESS'

if (-not (Get-Service "$serviceName" -ErrorAction SilentlyContinue)) {
  & "$PSScriptRoot\runtask.ps1" "powershell" "-ExecutionPolicy Bypass  -File $PSScriptRoot\install.ps1"
}

if (-not (Get-Service "$serviceName" -ErrorAction SilentlyContinue)) {
  echo "Service $serviceName not found."
  echo "Installation failed"
  exit 1
}

Start-Service $serviceName

try {
  do {
    # WaitForStatus method does not break when Stop-Job is invoked
    # (Get-Service 'MSSQL$SQLEXPRESS').WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped)
    $serviceStatus = (Get-Service "$serviceName").Status
    if ($serviceStatus -eq "Stopped") {
        echo "Service $serviceName stopped"
        break;
    }
    echo "Service $serviceName is $serviceStatus"
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
