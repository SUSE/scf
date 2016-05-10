$installScript = "$PSScriptRoot\install.ps1"

function GeneratePassword { param($BytesOfEntropy = 32)
    $randomBytes = New-Object Byte[]($BytesOfEntropy)
    ([Security.Cryptography.RNGCryptoServiceProvider]::Create()).GetBytes($randomBytes)
    return "a" + [System.Convert]::ToBase64String($randomBytes) + "aA1!"
}

$invokeTask = { param([string]$id, [string]$startFilename, [string]$startArgs, [Hashtable]$envVars)
    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $envVars.GetEnumerator() | %{ if ( -not (Test-Path env:"$($_.Key)")) { $StartInfo.EnvironmentVariables.Add($_.Key, $_.Value) } }
    $StartInfo.FileName = $startFilename
    $StartInfo.Arguments = $startArgs
    $StartInfo.UseShellExecute = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    $StartInfo.RedirectStandardInput = $true

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $StartInfo
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream("\\.\pipe\$id");
    $pipe.Connect(20000);

    $sw = New-Object System.IO.StreamWriter($pipe);
    $sw.AutoFlush = $true

    # Register Object Events for stdin\stdout reading
    $OutEvent = Register-ObjectEvent -InputObject $Process -EventName OutputDataReceived -Action {
        $mes = @{'type'= 'stdout'; 'value'= $Event.SourceEventArgs.Data}
        $sw.WriteLine(($mes | ConvertTo-Json -Compress))
    }

    $ErrEvent = Register-ObjectEvent -InputObject $Process -EventName ErrorDataReceived -Action {
        $mes = @{'type'= 'stderr'; 'value'= $Event.SourceEventArgs.Data}
        $sw.WriteLine(($mes | ConvertTo-Json -Compress))
    }

    $ExitEvent = Register-ObjectEvent -SourceIdentifier "$id-exitEvent" -InputObject $Process -EventName Exited

    # Start process
    $Process.Start()

    $pidMes = @{'type'= 'pid'; 'value'= $Process.Id}
    $sw.WriteLine(($pidMes | ConvertTo-Json -Compress))

    $Process.BeginOutputReadLine()
    $Process.BeginErrorReadLine()

    # Wait for exit
    Wait-Event "$id-exitEvent" | Out-Null

    # Cleanup
    Unregister-Event -SourceIdentifier $OutEvent.Name
    Unregister-Event -SourceIdentifier $ErrEvent.Name
    Unregister-Event -SourceIdentifier "$id-exitEvent"

    $exitMes = @{'type'= 'exit'; 'value'= $Process.ExitCode}
    $sw.WriteLine(($exitMes | ConvertTo-Json -Compress))

    $sw.Dispose()
    $pipe.Dispose()
}


$id = ("InvokeTask" + [guid]::NewGuid().ToString("N")).Substring(0, 20)
$idPassword = GeneratePassword
$idCredentials = New-Object System.Management.Automation.PSCredential $id,(ConvertTo-SecureString -AsPlainText -Force $idPassword)

Write-Output "Creating install helper user $id"
net user "$id" "$idPassword" /add /yes | Out-Null
net localgroup Administrators "$id" /add /yes | Out-Null

$envVars = @{}
gci env: | %{$envVars.Add($_.Name, $_.Value)}

$regs = Register-ScheduledJob -Name $id -ScriptBlock $invokeTask -ArgumentList $id, "powershell", "-ExecutionPolicy Bypass  -File $installScript", $envVars -ScheduledJobOption (New-ScheduledJobOption -RunElevated) -Credential $idCredentials

$pipe = New-Object System.IO.Pipes.NamedPipeServerStream("\\.\pipe\$id");

# Run the Schduled Task
$regs.RunAsTask()

$pipe.WaitForConnection();
$sr = New-Object System.IO.StreamReader($pipe);

$exitCode = 1

# Wait for exit message to break the loop and redirect the output form the pipe to stdout
while (($line = $sr.ReadLine()) -ne $null)
{
  $mes = ($line | ConvertFrom-Json)
  if ($mes.'type' -eq 'exit') {
    echo ( "Exit code from `"$installScript`": " + $mes.'value' )
    $exitCode = $mes.'value'
    break
  } elseif ($mes.'type' -eq 'stdout') {
    Write-Output $mes.'value'
  } elseif ($mes.'type' -eq 'stderr') {
    Write-Output $mes.'value'
  }
}

$sr.Dispose();
$pipe.Dispose();

# Wait for job name to be available, then wait for the job to stop, and then retreive the output of the job
foreach($i in 1..15) { if (Get-Job $id -ErrorAction SilentlyContinue) { break } sleep 1 }
Wait-Job $id -Timeout 5 | Out-Null
Receive-Job $id

# Cleanup
Unregister-ScheduledJob $id -Force
Write-Output "Cleaning up install helper user $id"
net user "$id" /delete /yes | Out-Null

exit $exitCode
