function ExtractSQLServer($sqlServerExpressPath, $sqlServerExtractionPath){
  Write-Output "Extracting SQL Server Express 2012"
  $argList = "/q", "/x:${sqlServerExtractionPath}"
  $extractProcess = Start-Process -Wait -PassThru -NoNewWindow $sqlServerExpressPath -ArgumentList $argList
  if ($extractProcess.ExitCode -ne 0)
  {
    throw "Failed to extract Sql Server Express 2012."
  }
  else
  {
    Write-Output "[OK] SQL Server Express extraction was successful."
  }
}