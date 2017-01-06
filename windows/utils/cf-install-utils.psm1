
function ConfigureCellLocalwall {
  param(
    [string]$LocalwallExePath = "localwall.exe",
    [string]$machineIp
  )

  Write-Output "Configuring WFP localhost filtering rules with $LocalwallExePath"

  & $LocalwallExePath cleanup

  & $LocalwallExePath add $machineIp 32 8301 Administrators # Consul rule
  & $LocalwallExePath add 127.0.0.1  8  8400 Administrators # Consul rule
  & $LocalwallExePath add 127.0.0.1  8  8500 Administrators # Consul rule

  & $LocalwallExePath add 127.0.0.1  8  3457 Administrators # Metron rule
  & $LocalwallExePath add $machineIp 32 6061 Administrators # Metron rule

  & $LocalwallExePath add $machineIp 32 1800 Administrators # Rep rule
  & $LocalwallExePath add $machineIp 32 1801 Administrators # Rep rule

  & $LocalwallExePath add 127.0.0.1  8  9241 Administrators # Garden rule

  & $LocalwallExePath add 127.0.0.1  8  1788 Administrators # Containerizer rule
}

function ConfigureCellWindowsFirewall {
  Write-Output "Configuring Windows Firewall"

  # Snippet source: https://github.com/cloudfoundry/garden-windows-release/blob/master/scripts/setup.ps1#L134
  $admins = New-Object System.Security.Principal.NTAccount("Administrators")
  $adminsSid = $admins.Translate([System.Security.Principal.SecurityIdentifier])

  $LocalUser = "D:(A;;CC;;;$adminsSid)"
  $otherAdmins = Get-WmiObject win32_groupuser |
    Where-Object { $_.GroupComponent -match 'Administrators' } |
    ForEach-Object { [wmi]$_.PartComponent }

  foreach($admin in $otherAdmins)
  {
    $ntAccount = New-Object System.Security.Principal.NTAccount($admin.Name)
    $sid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
    $LocalUser = $LocalUser + "(A;;CC;;;$sid)"
  }

  Remove-NetFirewallRule -Name CFAllowAdmins -ErrorAction Ignore
  New-NetFirewallRule -Name CFAllowAdmins -DisplayName "Allow admins" `
    -Description "Allow admin users" -RemotePort Any `
    -LocalPort Any -LocalAddress Any -RemoteAddress Any `
    -Enabled True -Profile Any -Action Allow -Direction Outbound `
    -LocalUser $LocalUser

  Set-NetFirewallProfile -All -DefaultInboundAction Allow -DefaultOutboundAction Block -Enabled True
}

function DisableNegativeDnsClientCache {
  New-Item 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -Force | `
    New-ItemProperty -Name MaxNegativeCacheTtl -PropertyType "DWord" -Value 1 -Force

  Clear-DnsClientCache
}

function UninstallGardenWindows {
  $gardenProduct = gwmi win32_product | ? {$_.name -match 'GardenWindows'}
  if ($gardenProduct) {
    echo "Uninstalling existing GardenWindows. `nDetails: $gardenProduct"
    $gardenProduct.Uninstall()
  }
}

function SetInterfaceForLocalipGoPackage {
  param(
    [parameter(Mandatory = $true)]
    [UInt32]$IntefaceIndex
  )

  # 1.2.3.4 is used by rep and metron to discover the IP address to be announced to the diego cluster
  # https://github.com/pivotal-golang/localip/blob/ca5f12419a47fe0c8547eea32f9498eb6e9fe817/localip.go#L7
  Remove-NetRoute -DestinationPrefix "1.2.3.4/32" -Confirm:$false -ErrorAction SilentlyContinue
  New-NetRoute -DestinationPrefix "1.2.3.4/32" -InterfaceIndex $IntefaceIndex
}

function IntalledRequiredWindowsFeatures {
  Write-Output "Installing Windows Features"
  Install-WindowsFeature  Web-Webserver, Web-WebSockets, AS-Web-Support, AS-NET-Framework, Web-WHC, Web-ASP
  Install-WindowsFeature  Web-Net-Ext45, Web-AppInit # Extra features for the cf-iis8-buildpack
}

function EnableDiskQuota {
  Write-Output "Enabling disk quota"
  fsutil quota enforce C:
}

function GetHttpString {
  [OutputType([string])]
  param(
    [parameter(Mandatory = $true)]
    [string]$Url,
    [parameter(Mandatory = $true)]
    [string]$Username,
    [parameter(Mandatory = $true)]
    [string]$Password,
    [bool]$SkipCertificateValidation = $false
  )

  $request = [System.Net.HttpWebRequest]::Create($Url)
  
  if ($SkipCertificateValidation) {
    $request.ServerCertificateValidationCallback = {$true}
  }

  $creds = "Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username, $Password)))
  $request.Headers.Set("Authorization", $creds)

  $response = $request.GetResponse()
  $requestStream = $response.GetResponseStream()
  $readStream = New-Object System.IO.StreamReader $requestStream

  return $readStream.ReadToEnd()
}

function GetConfigFromDemophon {
  [OutputType([System.Collections.Hashtable])]
  param(
    [parameter(Mandatory = $true)]
    [string]$Username,
    [parameter(Mandatory = $true)]
    [string]$Password,
    [parameter(Mandatory = $true)]
    [string]$DemaphonEndpoint,
    [bool]$SkipCertificateValidation = $false
  )

  $configResponse = GetHttpString -Url ($DemaphonEndpoint + "/v1/configuration") -Username $Username -Password $Password -SkipCertificateValidation $SkipCertificateValidation

  $configResult = ($configResponse | ConvertFrom-Json)
  $hcfSettings = New-Object System.Collections.Hashtable

  $configResult | % { $hcfSettings.Add( $_.name, $_.value -replace ( "\\n", "`n") ) }
  return $hcfSettings
}

Export-ModuleMember `
 ConfigureCellLocalwall, `
 ConfigureCellWindowsFirewall, `
 DisableNegativeDnsClientCache, `
 UninstallGardenWindows, `
 SetInterfaceForLocalipGoPackage, `
 IntalledRequiredWindowsFeatures, `
 EnableDiskQuota, `
 GetConfigFromDemophon
 
