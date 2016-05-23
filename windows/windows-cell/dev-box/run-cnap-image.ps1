function Mount-CNAPVHD{[CmdletBinding()]param($vhdPath, $mountPath)
  $image = Mount-DiskImage -ImagePath $vhdPath -StorageType VHDX -ErrorAction 'Stop' -PassThru -NoDriveLetter
  $volume = Get-DiskImage -ImagePath $vhdPath | Get-Disk | Get-Partition | Get-Volume
  mkdir -ErrorAction SilentlyContinue $mountPath
  $drive = Get-WmiObject win32_volume -Filter "DeviceID = '$($volume.ObjectID.Replace('\', '\\'))'" -ErrorAction Stop
  $drive.AddMountPoint($mountPath)
}

$cnapComponentName = "cnap"
$mountPath = "C:\cnap-image"
$vhdPath = "c:\cnap-image.vhdx"
$runScript = Join-Path $mountPath "run.ps1"
$zipFile = "C:\cnap-image.gz"

if (-not ((Get-DiskImage -ImagePath "C:\cnap-image.vhdx").Attached)) {
  Mount-CNAPVHD -vhdPath $vhdPath -mountPath $mountPath
}

#  Alternate way to run run.ps1:
# powershell.exe -ExecutionPolicy Bypass -NonInteractive -File $runScript

if (-not (Get-PSSession -ComputerName localhost -Name $cnapComponentName -ErrorAction SilentlyContinue)) {
  echo "Creating PSSession $cnapComponentName"

  # Save env vars in a Hashtable
  $envVars = @{}
  gci env: | %{$envVars.Add($_.Name, $_.Value)}

  $session = New-PSSession -Name $cnapComponentName -EnableNetworkAccess
  Invoke-Command -Session $session -ScriptBlock {param($cnapComponentName, $mountPath, $envVars)
    Start-Job -Name "$cnapComponentName" -ScriptBlock {param($mountPath, $envVars)
      $envVars.GetEnumerator() | %{ if ( -not ([Environment]::GetEnvironmentVariable($_.Key))) { [Environment]::SetEnvironmentVariable($_.Key, $_.Value) } }
      & (Join-Path "$mountPath" 'run.ps1')
    } -ArgumentList (, $mountPath, $envVars)
  } -ArgumentList (,$cnapComponentName, $mountPath, $envVars)
  Disconnect-PSSession -Session $session
} else {
  echo "PSSession $cnapComponentName exists"
}

echo "Waiting for run.ps1 job to complete"
do {
  sleep 2

  $session = Connect-PSSession -WarningAction silentlyContinue -ComputerName localhost -Name $cnapComponentName

  $jobState = Invoke-Command -WarningAction silentlyContinue -Session $session -ScriptBlock {param($cnapComponentName)
    (Get-Job -Name $cnapComponentName).State
  } -ArgumentList (,$cnapComponentName)

  Invoke-Command -WarningAction silentlyContinue -Session $session -ScriptBlock {param($cnapComponentName)
    Receive-Job -Name $cnapComponentName
  } -ArgumentList (,$cnapComponentName)

  if ($jobState -ne "Running") {
    echo "run.ps1 job state changed from Running to: $jobState"
  }

  Disconnect-PSSession -Session $session -WarningAction Ignore | Out-Null

} while ($jobState -eq "Running")

Get-PSSession -ComputerName localhost -Name $cnapComponentName -ErrorAction SilentlyContinue | Remove-PSSession -ErrorAction SilentlyContinue
