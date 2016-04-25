$wd=$PSScriptRoot
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$sqlServerExtractionPath = Join-Path $wd "SQLEXPRWT_x64_ENU"
if (!$saPasswd) { $saPasswd = "INullPeer0000" }
if (!$sqlDataDir) { $sqlDataDir = "c:\SQLDatabases" }

$sqlCmdBin = 'c:\Program Files\Microsoft SQL Server\110\Tools\Binn\sqlcmd.exe'

function InstallSqlServer()
{
	Write-Output "Installing SQL Server Express 2012"

	$argList = "/ACTION=Install", "/INDICATEPROGRESS", "/Q", "/UpdateEnabled=False", "/FEATURES=SQLEngine", "/INSTANCENAME=SQLEXPRESS",
    	            "/INSTANCEID=SQLEXPRESS","/X86=False", "/SQLSVCSTARTUPTYPE=Automatic","/SQLSYSADMINACCOUNTS=Administrator",
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
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL11.SQLEXPRESS\MSSQLServer\SuperSocketNetLib\Tcp\IPAll' -Name TcpDynamicPorts -Value ""
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL11.SQLEXPRESS\MSSQLServer\SuperSocketNetLib\Tcp\IPAll' -Name TcpPort -Value 1433

    Write-Output "Restarting SQL Server"
    Restart-Service 'MSSQL$SQLEXPRESS'
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