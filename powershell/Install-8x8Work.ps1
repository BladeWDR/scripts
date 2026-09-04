<#
  .DESCRIPTION Installs 8x8 work by scraping their web page for the MSI installer.
#>
#Requires -RunAsAdministrator

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11

$WebUrl = 'https://help.8x8.com/docs/download-8x8-work-for-desktop'
$links = New-Object System.Collections.ArrayList
$TEMP = "$env:TEMP\8x8work_$(Get-Random)"
$8x8DownloadFile = '8x8work.msi'
$8x8DownloadPath = "$TEMP\$8x8DownloadFile"

if (-not (Test-Path -Path $TEMP))
{
  New-Item -Path $TEMP -ItemType Directory -Force | Out-Null
}


function Invoke-ScrapeWebpage
{

  param(
    [string]$Url
  )

  try
  {
    $webpage = Invoke-WebRequest -Uri $Url -UseBasicParsing

    return $webpage.Links
  } catch
  {
    Write-Error "Error when trying to scrap web page. $_"
    exit 1
  }
}

function Invoke-DownloadMsi
{
  param(
    [string]$Url,
    [string]$Path
  )

  try
  {
    Invoke-WebRequest -Uri "$Url" -UseBasicParsing -OutFile "$Path"
  } catch
  {
    Write-Error "Failed to download 8x8 work MSI. $_" 
    exit 1
  }
}

function Install-Program
{
  param(
    [string]$Executable,
    [string]$ExeArgs,
    [string]$Name
  )

  Write-Host "Installing $Name..."
  Write-Host "Executing: $Executable $ExeArgs"

  try
  {
    $process = Start-Process -FilePath $Executable -ArgumentList $ExeArgs -Wait -NoNewWindow -PassThru -ErrorAction Stop
    $exitCode = $process.ExitCode

    # Exit code 0 = Success, 3010 = Success (Reboot Required)
    if ($exitCode -eq 0 -or $exitCode -eq 3010)
    {
      Write-Host "SUCCESS: $Name installed successfully (Exit Code: $exitCode)."
    } else
    {
      Write-Error "ERROR: $Name installation failed with Exit Code $exitCode."
      Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
      exit 1
    }
  } catch
  {
    Write-Error "ERROR: Failed to launch installer for $Name. $_"
    Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
  }
}

$WebContent = Invoke-ScrapeWebpage -Url "$WebUrl"

# Match on any version string, then find the latest one by casting the version string to an object and sorting it.
$pattern = 'https://work-desktop-assets\.8x8\.com/prod-publish/ga/work-64-msi-v[\d.]+-\d+\.msi'

foreach($chunk in $WebContent )
{
  if($($chunk.href) -match $pattern)
  {
    [void]$links.Add($chunk.href)
  }
}

$newest = $links |
  Sort-Object {
    if ($_ -match 'work-64-msi-v([\d.]+)-(\d+)\.msi')
    {
      [version]("$($Matches[1]).$($Matches[2])")
    }
  } -Descending |
  Select-Object -First 1

Invoke-DownloadMsi -Url "$newest" -Path "$8x8DownloadPath"
Install-Program -Executable 'msiexec.exe' -ExeArgs "/i `"$8x8DownloadPath`" /qn /norestart" -Name "8x8 Work Desktop Client"
exit 0
