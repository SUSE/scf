<#
.SYNOPSIS
    Packaging and installation script for Windows Diego Compoents for HCF with HCP
.DESCRIPTION
    This script packages all the binaries into an self-extracting file.
    Upon self-extraction this script is run to unpack and start the installation.
.NOTES
    Author: Hewlett-Packard Enterprise Development Company
    Date:   November, 2015
#>

param (
)

$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent
$resourcesDir = Join-Path $currentDir "resources"
$deployDir = Join-Path $currentDir "../deploy"

Import-Module -DisableNameChecking (Join-Path $currentDir '../deploy/common/utils.psm1')



function Download-Resources() {
    $resourceFile = Join-Path $currentDir "resources.csv"
    $resources = Import-Csv $resourceFile

    if (Test-Path $resourcesDir){
        Remove-Item $resourcesDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $resourcesDir | Out-Null

    foreach ($resource in $resources){
        $resourcePath = Join-Path $resourcesDir $resource.path
        $parentPath = Split-Path -Path $resourcePath
        if (!(Test-Path $parentPath)){
            New-Item -ItemType Directory -Path $parentPath | Out-Null
        }

        Write-Output "Downloading resource '${resourcePath}'"
        Download-File-With-Retry $resource.uri $resourcePath
        Write-Output "[OK] Resource downloaded."
    }

    Write-Output "[OK] Resources successfully downloaded."
}

function Create-ZipFile($folder, $achiveName){
    Write-Output "Creating zip '${$destFile}' ..."

    [Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" ) | out-null

    $destFile = Join-Path $(Get-Location) $achiveName
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    $includeBaseDir = $false
    Remove-Item -Force -Path $destFile -ErrorAction SilentlyContinue

    Write-Output 'Creating zip archive ...'

    [System.IO.Compression.ZipFile]::CreateFromDirectory($folder, $destFile, $compressionLevel, $includeBaseDir)

    Write-Output "[OK] Created zip archive"
    return $destFile
}


function DoAction-Package()
{
    Download-Resources

    $resourceArchive = Create-ZipFile $resourcesDir "resources.zip"
    $deployArchive = Create-ZipFile $deployDir "deploy.zip"

    Write-Output 'Creating the self extracting exe ...'

    $installerProcess = Start-Process -Wait -PassThru -NoNewWindow 'iexpress' "/N /Q helion-windows.SED"

    if ($installerProcess.ExitCode -ne 0)
    {
        Write-Error "There was an error building the installer. Exit code: ${installerProcess.ExitCode}"
        exit 1
    }

    Write-Output 'Removing artifacts ...'
    Remove-Item -Force -Path $resourceArchive -ErrorAction SilentlyContinue
    Remove-Item -Force -Path $deployArchive -ErrorAction SilentlyContinue
    Remove-Item  $resourcesDir -Recurse -Force

    Write-Output 'Done.'
}

DoAction-Package
