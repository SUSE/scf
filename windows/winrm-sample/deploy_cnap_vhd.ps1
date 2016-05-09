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

if ([string]::IsNullOrWhiteSpace($env:VHD_URL))
{
  $env:VHD_URL = "https://s3-us-west-1.amazonaws.com/clients.als.hpcloud.com/ro-artifacts/hcf-mssql2012-vhds/2-2016-04-27_09-00-13/mssql2012.gz"
}
$vhdUrl = $env:VHD_URL

$mountPath = "C:\cnap-image"
$vhdPath = "c:\cnap-image.vhdx"
$runScript = Join-Path $mountPath "run.ps1"
$zipFile = "C:\cnap-image.gz"

Write-Host "Downloading $zipFile from $vhdUrl ..."
(New-Object System.Net.WebClient).DownloadFile($vhdUrl, $zipFile)

Write-Host "Unpacking $zipFile to $vhdPath ..."

$fileInput = New-Object System.IO.FileStream $zipFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
$fileOutput = New-Object System.IO.FileStream $vhdPath, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
$stream = New-Object System.IO.Compression.GzipStream $fileInput, ([IO.Compression.CompressionMode]::Decompress)

$buffer = New-Object byte[](1024)
while($true){
  $read = $stream.Read($buffer, 0, 1024)
  if ($read -le 0){break}
  $fileOutput.Write($buffer, 0, $read)
}

$stream.Close()
$fileOutput.Close()
$fileInput.Close()

Mount-CNAPVHD -vhdPath $vhdPath -mountPath $mountPath
powershell.exe -ExecutionPolicy Bypass -NoLogo -File $runScript
Dismount-CNAPVHD -vhdPath $vhdPath -mountPath $mountPath
Remove-Item $vhdPath
