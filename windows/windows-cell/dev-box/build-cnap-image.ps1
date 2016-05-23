# Add msbuild.exe to PATH
$env:PATH="${env:PATH};${env:WINDIR}\Microsoft.NET\Framework64\v4.0.30319"

Dismount-DiskImage  C:\cnap-image.vhdx -ErrorAction SilentlyContinue
Get-CimInstance Win32_MountPoint | ? {$_.Directory.Name -like "C:\cnap-image" } | Remove-CimInstance
cmd /c rmdir C:\cnap-image  # http://kristofmattei.be/2012/12/15/powershell-remove-item-and-symbolic-links/

Dismount-DiskImage  C:\hcf-windows\windows-cell\windows-cell.vhdx -ErrorAction SilentlyContinue
Get-CimInstance Win32_MountPoint | ? {$_.Directory.Name -like "C:\hcf-windows\*" } | Remove-CimInstance
Remove-Item C:\hcf-windows\ -Force -Recurse

Copy-Item c:\hcf\windows\ c:\hcf-windows\ -Force -Recurse -Verbose

cd "C:\hcf-windows\windows-cell"

msbuild /t:Build

Copy-Item C:\hcf-windows\windows-cell\windows-cell.vhdx C:\cnap-image.vhdx -Force
