$wd=$PSScriptRoot

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"


if ([string]::IsNullOrWhiteSpace($env:MSSQL_SA_PASSWORD))
    {
        throw "No password for MSSQL 2012 provided."
    }
$saPasswd = $env:MSSQL_SA_PASSWORD

if ([string]::IsNullOrWhiteSpace($env:MSSQL_DATADIR))
    {
        $env:MSSQL_DATADIR = "c:\SQLDatabases"
    }
$sqlDataDir = $env:MSSQL_DATADIR

if ([string]::IsNullOrWhiteSpace($env:MSSQL_TCPPORT))
    {
        $env:MSSQL_TCPPORT = "1433"
    }
$sqlTcpPort = $env:MSSQL_TCPPORT


$sqlServerExtractionPath = (Join-Path $wd "SQLEXPR_x64_ENU")

$sqlCmdBin = 'c:\Program Files\Microsoft SQL Server\110\Tools\Binn\sqlcmd.exe'

function InstallSqlServer()
{
	Write-Output "Installing SQL Server Express 2012"

	$argList = "/ACTION=Install", "/INDICATEPROGRESS", "/Q", "/UpdateEnabled=False", "/FEATURES=SQLEngine", "/INSTANCENAME=SQLEXPRESS",
            	    "/INSTANCEID=SQLEXPRESS","/X86=False", "/SQLSVCSTARTUPTYPE=Automatic","/SQLSYSADMINACCOUNTS=`"BUILTIN\ADMINISTRATORS`"",
            	    "/ADDCURRENTUSERASSQLADMIN=False","/TCPENABLED=1","/NPENABLED=0","/SECURITYMODE=SQL","/IACCEPTSQLSERVERLICENSETERMS",
            	    "/SAPWD=${saPasswd}","/INSTALLSQLDATADIR=${sqlDataDir}"

	$sqlServerSetup = Join-Path $sqlServerExtractionPath "SETUP.EXE"

	$installSQLServerProcess = Start-Process -Wait -PassThru -NoNewWindow $sqlServerSetup -ArgumentList $argList


	if ($installSQLServerProcess.ExitCode -lt 0)
	{
        $exitCode = $installSQLServerProcess.ExitCode
		throw "Failed to install Sql Server Express 2012 exit code ${exitCode}"
	}
	else
	{
		Write-Output "[OK] SQL Server Express installation was successful."
	}
}

function EnableStaticPort()
{
    Write-Output "Enabling TCP access to SQL Server"

    $regPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL11.SQLEXPRESS\MSSQLServer\SuperSocketNetLib\Tcp\IPAll"

    if (!(Get-ItemProperty "$regPath").'TcpPort')  {
    New-ItemProperty -Path "$regPath" -Name 'TcpPort' -Value "$sqlTcpPort" -Force } else {
    Set-ItemProperty -Path "$regPath" -Name TcpPort -Value "$sqlTcpPort"
    }

    if (!(Get-ItemProperty "$regPath").'TcpDynamicPorts') {
    New-ItemProperty -Path "$regPath" -Name 'TcpDynamicPorts' -Value '' -Force } else {
    Set-ItemProperty -Path "$regPath" -Name 'TcpDynamicPorts' -Value ''
    }

    Write-Output "Restarting SQL Server"
    Restart-Service 'MSSQL$SQLEXPRESS'

    Write-Output "Opening port $sqlTcpPort in firewall"

    $fwPolicy = New-Object -ComObject HNetCfg.FwPolicy2
    $rule = New-Object -ComObject HNetCfg.FWRule
    $rule.Name = 'MyPort'
    $rule.Profiles = 2147483647
    $rule.Enabled = $true
    $rule.Action = 1
    $rule.Direction = 1
    $rule.Protocol = 6
    $rule.LocalPorts = $sqlTcpPort

    $fwPolicy.Rules.Add($rule)

    Write-Output "Firewall updated"
}

function EnableContainedDatabaseAuthentication()
{
    Write-Output "Enable contained database authentication"

    $argList = "-S .\sqlexpress","-U sa", "-P ${saPasswd}", "-Q `"EXEC sp_configure `'contained database authentication`', 1; reconfigure;`""
    $sqlCmdProcess = Start-Process -Wait -PassThru -NoNewWindow $sqlCmdBin -ArgumentList $argList

    if ($sqlCmdProcess.ExitCode -ne 0)
    {
        $exitCode = $installSQLServerProcess.ExitCode
		throw "Failed to enable contained database authentication, exit code ${exitCode}"
    }

}

function AddSystemUser()
{
    Write-Output "Adding system user"

    $argList = "-S .\sqlexpress","-U sa", "-P ${saPasswd}", "-Q `"ALTER SERVER ROLE [sysadmin] ADD MEMBER [NT AUTHORITY\SYSTEM];`""

    $sqlCmdProcess = Start-Process -Wait -PassThru -NoNewWindow $sqlCmdBin -ArgumentList $argList

    if ($sqlCmdProcess.ExitCode -ne 0)
    {
        $exitCode = $installSQLServerProcess.ExitCode
		throw "Failed to enable contained database authentication, exit code ${exitCode}"
    }
}

function InstallWindowsFeatures()
{
	Install-WindowsFeature -Name Net-Framework-Core -Source D:\sources\sxs
}

InstallWindowsFeatures
InstallSqlServer
EnableStaticPort
EnableContainedDatabaseAuthentication
AddSystemUser
