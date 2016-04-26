## Read HCF Settings

$hcfSettings = New-Object System.Collections.Hashtable
$hcfCertsConfig = New-Object System.Collections.Hashtable
(cat "C:\hcf\bin\dev-settings.env") -split '`n' |  % { $s = $_ -split ('=', 2); $hcfSettings.Add( $s[0], $s[1] ) }
(cat "C:\hcf\bin\dev-certs.env") -split '`n' | % { $s = $_ -split ('=', 2); $hcfCertsConfig.Add( $s[0], $s[1] -replace ( "\\n", "`n") ) }


## Setup HTTP proxy

$env:HTTP_PROXY = $hcfSettings.'HTTP_PROXY'
$env:HTTPS_PROXY = $hcfSettings.'HTTPS_PROXY'
$env:NO_PROXY = $hcfSettings.'NO_PROXY'

$proxyServers = ""

if ($env:HTTP_PROXY -and $env:HTTPS_PROXY -and ($env:HTTP_PROXY -ne "") -and ($env:HTTPS_PROXY -ne "")) {

    if ($env:HTTP_PROXY -and ($env:HTTP_PROXY -ne "")) {
        $proxyServers += "http=$env:HTTP_PROXY"
    }

    if ($env:HTTPS_PROXY -and ($env:HTTPS_PROXY -ne "")) {
        if ($proxyServers -ne "") { $proxyServers += ";" }
        $proxyServers += "https=$env:HTTPS_PROXY"
    }

    $bypassList = ($env:NO_PROXY -replace ',', ';')

    route delete 0.0.0.0 -p

    echo "Setting proxy servers     : $proxyServers"
    echo "Setting proxy bypass list : $bypassList"

    # Set proxy for WinHTTP
    netsh winhttp set proxy proxy-server="$proxyServers" bypass-list="$bypassList"

    # Set proxy for WinINET at machine level
    $proxyRegPath = "Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $ieSettings64 = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64).OpenSubKey($proxyRegPath, $true)
    $ieSettings32 = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32).OpenSubKey($proxyRegPath, $true)
    $setProxy = { param ($ieRegKey)
        $ieRegKey.SetValue("AutoDetect", 0)
        $ieRegKey.SetValue("ProxyEnable", 1)
        $ieRegKey.SetValue("ProxyServer", $proxyServers, [Microsoft.Win32.RegistryValueKind]::String)
        $ieRegKey.SetValue("ProxyOverride", $bypassList)
    }

    & $setProxy $ieSettings64
    & $setProxy $ieSettings32


    $proxyPolicyRegPath = "Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"

    $iePolicySettings64 = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64).OpenSubKey($proxyPolicyRegPath, $true)
    $iePolicySettings32 = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32).OpenSubKey($proxyPolicyRegPath, $true)
    $setProxyPolicy = { param ($ieRegKey)
        $ieRegKey.SetValue("ProxySettingsPerUser", 0)
    }

    & $setProxyPolicy $iePolicySettings64
    & $setProxyPolicy $iePolicySettings32
}
