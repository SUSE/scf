function New-CNAPVHD{[CmdletBinding()]param($vhdPath, $sizeInMB)
  $diskpartScriptPath = "${vhdPath}.diskpart"
  $diskPartScript = @"
create vdisk file="${vhdPath}" maximum=${sizeInMB} type=expandable
select vdisk file="${vhdPath}"
attach vdisk
convert mbr
create partition primary
assign
format fs="ntfs" label="System" quick
active
detach vdisk
exit
"@
  $diskPartScript | Out-File -Encoding 'ASCII' $diskpartScriptPath

  try
  {
    $diskpartProcess = Start-Process -Wait -PassThru -NoNewWindow 'diskpart' "/s `"${diskpartScriptPath}`""

    if ($diskpartProcess.ExitCode -ne 0)
    {
    throw 'Creating and formatting VHD failed.'
    }
  }
  finally
  {
    Remove-Item $diskpartScriptPath
  }
}

function Mount-CNAPVHD{[CmdletBinding()]param($vhdPath, $mountPath)
  $image = Mount-DiskImage -ImagePath $vhdPath -StorageType VHDX -ErrorAction 'Stop' -PassThru -NoDriveLetter
  $volume = Get-DiskImage -ImagePath $vhdPath | Get-Disk | Get-Partition | Get-Volume
  mkdir -ErrorAction SilentlyContinue $mountPath
  $drive = Get-WmiObject win32_volume -Filter "DeviceID = '$($volume.ObjectID.Replace('\', '\\'))'" -ErrorAction Stop
  $drive.AddMountPoint($mountPath)
}

function Dismount-CNAPVHD{[CmdletBinding()]param($vhdPath, $mountPath)
  If (Test-Path $vhdPath){
    Dismount-DiskImage -ImagePath $vhdPath
  }
  If (Test-Path $mountPath){
    [System.IO.Directory]::Delete($mountPath, $true)
  }
}