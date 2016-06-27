## Read HCF Settings

$hcfSettings = New-Object System.Collections.Hashtable
$hcfCertsConfig = New-Object System.Collections.Hashtable
(cat "C:\hcf\bin\settings-dev\settings.env") -split '`n' |  % { $s = $_ -split ('=', 2); $hcfSettings.Add( $s[0], $s[1] ) }
(cat "C:\hcf\bin\settings-dev\certs.env") -split '`n' | % { $s = $_ -split ('=', 2); $hcfCertsConfig.Add( $s[0], $s[1] -replace ( "\\n", "`n") ) }

## Setup HTTP proxy

$env:HTTP_PROXY = $hcfSettings.'HTTP_PROXY'
$env:HTTPS_PROXY = $hcfSettings.'HTTPS_PROXY'
$env:NO_PROXY = $hcfSettings.'NO_PROXY'

if ($env:HTTP_PROXY -and $env:HTTPS_PROXY -and ($env:HTTP_PROXY -ne "") -and ($env:HTTPS_PROXY -ne "")) {

    $hklm64 = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
    $hklm32 = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32)

    ## Disable IE first run wizard
    ## https://www.petri.com/disable-ie8-ie9-welcome-screen
    $ieMainRegPath = "Software\Policies\Microsoft\Internet Explorer\Main"
    $disableWizard = { param ($ieRegKey)
        $ieMainSettings = $ieRegKey.CreateSubKey($ieMainRegPath, $true)
        $ieMainSettings.SetValue("DisableFirstRunCustomize", 1)
        $ieMainSettings.Dispose()
    }

    & $disableWizard $hklm64
    & $disableWizard $hklm32


    ## Parse proxy env

    $proxyServers = ""

    if ($env:HTTP_PROXY -and ($env:HTTP_PROXY -ne "")) {
        $proxyServers += "http=$env:HTTP_PROXY"
    }

    if ($env:HTTPS_PROXY -and ($env:HTTPS_PROXY -ne "")) {
        if ($proxyServers -ne "") { $proxyServers += ";" }
        $proxyServers += "https=$env:HTTPS_PROXY"
    }

    $bypassList = ($env:NO_PROXY -replace ',', ';')

    echo "Setting proxy servers     : $proxyServers"
    echo "Setting proxy bypass list : $bypassList"


    # Disable ProxySettingsPerUser
    $proxyPolicyRegPath = "Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
    $setProxyPolicy = { param ($ieRegKey)
        $iePolicySettings = $ieRegKey.CreateSubKey($proxyPolicyRegPath, $true)
        $iePolicySettings.SetValue("ProxySettingsPerUser", 0)
        $iePolicySettings.Dispose()
    }

    & $setProxyPolicy $hklm64
    & $setProxyPolicy $hklm32

    # Set proxy for WinINET at machine level
    $proxyRegPath = "Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $setProxy = { param ($ieRegKey)
        $ieSettings = $ieRegKey.CreateSubKey($proxyRegPath, $true)
        $ieSettings.SetValue("AutoDetect", 0)
        $ieSettings.SetValue("ProxyEnable", 1)
        $ieSettings.SetValue("MigrateProxy", 0)
        $ieSettings.SetValue("ProxyServer", $proxyServers, [Microsoft.Win32.RegistryValueKind]::String)
        $ieSettings.SetValue("ProxyOverride", $bypassList)
        $ieSettings.Dispose()
    }

    & $setProxy $hklm64
    & $setProxy $hklm32

    $hklm64.Dispose()
    $hklm32.Dispose()

    # Set proxy for WinHTTP
    netsh winhttp set proxy proxy-server="$proxyServers" bypass-list="$bypassList"

    # Run Internet Explorer with an interactive logon token to
    # initialize the system proxy.
    # I agree, it is weird, but it is the only workaround that does not require
    # the user to RDP into the box and initialize IE.
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "powershell.exe"
    $startInfo.Arguments = "/c", "(new-object -ComObject internetexplorer.application).navigate('dummy-url')"
    $startInfo.RedirectStandardOutput = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $false
    $startInfo.Username = "vagrant"
    $startInfo.Password = (ConvertTo-SecureString "vagrant" -AsPlainText -Force)
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $process.Start()
    $process.WaitForExit()
}
