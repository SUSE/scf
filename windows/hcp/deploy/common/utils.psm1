$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

function Check-IsAdmin{[CmdletBinding()]param()
  Write-Verbose "Checking to see if we're running in an adminstrative shell ..."
  $wid = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $prp = new-object System.Security.Principal.WindowsPrincipal($wid)
  $adm = [System.Security.Principal.WindowsBuiltInRole]::Administrator
  $isAdmin = $prp.IsInRole($adm)
  if(!$isAdmin)
  {
      throw "This cmdlet must be executed in an elevated administrative shell"
  }
}

function Clean-Dir{[CmdletBinding()]param($path)
  Write-Verbose "Cleaning directory ${$path}"
  rm -Recurse -Force -Confirm:$false $path -ErrorAction SilentlyContinue
  mkdir $path -ErrorAction 'Stop' | out-null
}

function Download-File-With-Retry{[CmdletBinding()]param($url, $targetFile)
  $retry_left = 5
    while ($true) {
      try {
        Download-File $url $targetFile
        break
      }
      catch {
        if ($retry_left -lt 1) {
          throw
          }
          else {
            $errorMessage = $_.Exception.Message
            Write-Output "Call failed with exception: ${errorMessage}"
            Write-Verbose $_.Exception
            $retry_left = $retry_left - 1
            Write-Output "Retries left: ${retry_left}"
         }
      }

  }
}


function Download-File{[CmdletBinding()]param($url, $targetFile)
  Write-Verbose "Downloading '${url}' to '${targetFile}'"
  try {
    $uri = New-Object "System.Uri" "$url"
    $request = [System.Net.HttpWebRequest]::Create($uri)
    $request.set_Timeout(15000) #15 second timeout
    $request.set_KeepAlive($false)
    $response = $request.GetResponse()
    $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
    $responseStream = $response.GetResponseStream()
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
    $buffer = new-object byte[] 50KB
    $count = $responseStream.Read($buffer,0,$buffer.length)
    $downloadedBytes = $count
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    while ($count -gt 0) {
      $targetStream.Write($buffer, 0, $count)
      $count = $responseStream.Read($buffer,0,$buffer.length)
      $downloadedBytes = $downloadedBytes + $count

      if ($sw.Elapsed.TotalMilliseconds -ge 500) {
        $activity = "Downloading file '$($url.split('/') | Select -Last 1)'"
        $status = "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): "
        $percentComplete = ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
        Write-Progress -activity $activity -status $status -PercentComplete $percentComplete

        $sw.Reset()
        $sw.Start()
      }
    }

    Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -Completed -status "Done"
  }
  finally {
    if ($targetStream -ne $null) {
      $targetStream.Flush()
      $targetStream.Close()
      $targetStream.Dispose()
    }
    if ($responseStream -ne $null) {
      $responseStream.Dispose()
    }
  }
}
