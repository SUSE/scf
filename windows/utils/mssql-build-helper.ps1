function ExtractSQLServer($sqlServerExpressPath, $sqlServerExtractionPath){
  Write-Output "Extracting SQL Server Package"
  $argList = "/q", "/x:${sqlServerExtractionPath}"
  $extractProcess = Start-Process -Wait -PassThru -NoNewWindow $sqlServerExpressPath -ArgumentList $argList
  if ($extractProcess.ExitCode -ne 0)
  {
    throw "Failed to extract SQL Server Package."
  }
  else
  {
    Write-Output "[OK] SQL Server Express extraction was successful."
  }
}
