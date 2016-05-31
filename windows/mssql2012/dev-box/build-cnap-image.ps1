# Add msbuild.exe to PATH
$env:PATH="${env:PATH};${env:WINDIR}\Microsoft.NET\Framework64\v4.0.30319"

Dismount-DiskImage  C:\cnap-image.vhdx -ErrorAction SilentlyContinue
Get-CimInstance Win32_MountPoint | ? {$_.Directory.Name -like "C:\cnap-image" } | Remove-CimInstance
cmd /c rmdir C:\cnap-image

Dismount-DiskImage  C:\hcf-windows\mssql2012\mssql2012.vhdx -ErrorAction SilentlyContinue
Get-CimInstance Win32_MountPoint | ? {$_.Directory.Name -like "C:\hcf-windows\*" } | Remove-CimInstance
Remove-Item C:\hcf-windows\ -Force -Recurse

Copy-Item c:\hcf\windows\ c:\hcf-windows\ -Force -Recurse -Verbose

cd "C:\hcf-windows\mssql2012"

msbuild /t:Build

Copy-Item C:\hcf-windows\mssql2012\mssql2012.vhdx C:\cnap-image.vhdx -Force
