$coreIpAddress = "192.168.77.77"

## Read HCF Settings

$hcfSettings = New-Object System.Collections.Hashtable
(cat "C:\hcf\bin\settings\settings.env") -split '`n' |  % { $s = $_ -split ('=', 2); $hcfSettings.Add( $s[0], $s[1] ) }
(cat "C:\hcf\bin\settings\certs.env") -split '`n' | % { $s = $_ -split ('=', 2); $hcfSettings.Add( $s[0], $s[1] -replace ( "\\n", "`n") ) }


## Prepare diego configs parameters

$env:DIEGO_INSTALL_DIR = "c:\diego"
$env:DIEGO_USER_PASSWORD = "changeme1234!"

$env:REP_CELL_ID = $env:COMPUTERNAME
$env:DIEGO_CELL_IP = (Find-NetRoute -RemoteIPAddress $coreIpAddress)[0].IPAddress
$env:STACKS = "win2012r2;windows2012R2"
$env:REP_ZONE = "windows"
$env:REP_MEMORY_MB = "8192" # "auto"

$env:CONSUL_SERVER_IP = 'consul'
$env:CONSUL_ENCRYPT_KEY = $hcfSettings.'CONSUL_ENCRYPTION_KEYS'
$env:CONSUL_CA_CRT = $hcfSettings.'CONSUL_CA_CERT'
$env:CONSUL_AGENT_CRT = $hcfSettings.'CONSUL_AGENT_CERT'
$env:CONSUL_AGENT_KEY = $hcfSettings.'CONSUL_AGENT_KEY'

$env:BBS_CA_CRT = $hcfSettings.'BBS_CA_CRT'
$env:BBS_CLIENT_CRT = $hcfSettings.'BBS_CLIENT_CRT'
$env:BBS_CLIENT_KEY = $hcfSettings.'BBS_CLIENT_KEY'
$env:BBS_ADDRESS = 'https://diego-database:8889'

$env:ETCD_CLUSTER = 'http://etcd:4001'
$env:LOGGRAGATOR_SHARED_SECRET = $hcfSettings.'LOGGREGATOR_SHARED_SECRET'
$env:LOGGREGATOR_JOB = $env:COMPUTERNAME
$env:LOGGRAGATOR_INDEX = 0
