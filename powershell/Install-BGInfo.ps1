[CmdletBinding()]
param(
  [switch]$Force
)

# Datto RMM passes component variables as environment variables.
# This checks if the local -Force switch is used OR if the RMM variable is true/1/yes.
$isForce = $Force.IsPresent -or ($env:Force -match '(?i)^(true|1|yes)$')

$BgInfoUrl = 'https://download.sysinternals.com/files/BGInfo.zip'
$OutputDir = 'C:\IT'
$BgInfoDownloadFile = "$OutputDir\BGInfo.zip"
$BgInfoFilePath = "$OutputDir\Bginfo64.exe"
$BgInfoConfigPath = "$OutputDir\bginfo.bgi"
$StartupScriptPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\bginfo.bat"

$BatchScriptContent = @"
@echo off
"$BgInfoFilePath" "$BgInfoConfigPath" /nolicprompt /timer:0
exit
"@

if (-not (Test-Path -Path $OutputDir))
{
  New-Item -Path $OutputDir -ItemType Directory | Out-Null
}

# 1. Download and Extract BgInfo (Only if missing or Force is used)
if (-not (Test-Path -Path $BgInfoFilePath) -or $isForce)
{
  try
  {
    Write-Host "INFO: Downloading BGInfo.zip from Sysinternals..."
    # Ensure TLS 1.2 is enabled for PowerShell 5.1 compatibility
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $BgInfoUrl -OutFile $BgInfoDownloadFile
  } catch
  {
    Write-Error "ERROR: Failed to download BGInfo.zip. $_"
    exit 1
  }

  Write-Host "INFO: Extracting BgInfo.zip..."
  Expand-Archive -Path $BgInfoDownloadFile -DestinationPath $OutputDir -Force

  # Clean up the downloaded zip file
  Remove-Item -Path $BgInfoDownloadFile -Force -ErrorAction SilentlyContinue
} else
{
  Write-Host "INFO: BgInfo64.exe is already present in $OutputDir. Skipping download."
}

# 2. Ensure Configuration and Startup Script are always deployed (Idempotency)
Write-Host "INFO: Copying BgInfo Config file..."
# Use $PSScriptRoot so the script can run headlessly from any working directory
$SourceConfig = Join-Path -Path $PSScriptRoot -ChildPath "bginfo.bgi"
if (Test-Path -Path $SourceConfig)
{
  Copy-Item -Path $SourceConfig -Destination $BgInfoConfigPath -Force
} else
{
  Write-Error "ERROR: Could not find bginfo.bgi in the script directory."
  exit 1
}

Write-Host "INFO: Creating Startup Script..."
Set-Content -Path $StartupScriptPath -Value $BatchScriptContent -Force

Write-Host "INFO: Applying BgInfo to currently logged-on users..."
# Find all users currently running an active desktop session (explorer.exe)
$explorerProcesses = Get-CimInstance -ClassName Win32_Process -Filter "Name='explorer.exe'"

if ($explorerProcesses)
{
  foreach ($process in $explorerProcesses)
  {
    $owner = Invoke-CimMethod -InputObject $process -MethodName GetOwner
    $activeUser = "$($owner.Domain)\$($owner.User)"
    
    Write-Host "INFO: Triggering BgInfo for user session: $activeUser"
    $taskName = "TCG_BgInfo_Deploy_$($owner.User)"
    
    # Create a scheduled task that runs as the interactive user
    $action = New-ScheduledTaskAction -Execute $BgInfoFilePath -Argument "`"$BgInfoConfigPath`" /nolicprompt /timer:0"
    $principal = New-ScheduledTaskPrincipal -UserId $activeUser -LogonType Interactive
    $task = New-ScheduledTask -Action $action -Principal $principal
    
    try
    {
      Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
      Start-ScheduledTask -TaskName $taskName | Out-Null
      
      # Wait briefly to ensure it runs before cleanup
      Start-Sleep -Seconds 3
      
      Unregister-ScheduledTask -TaskName $taskName -Confirm:$false | Out-Null
    } catch
    {
      Write-Error "ERROR: Failed to trigger BgInfo for user $activeUser. $_"
    }
  }
} else
{
  Write-Host "INFO: No active user sessions found. BgInfo will apply at next logon."
}

Write-Host "INFO: BgInfo deployment complete."
exit 0
