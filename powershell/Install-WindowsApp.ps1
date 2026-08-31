<#
.SYNOPSIS
    Automated silent installer for Microsoft Windows App (Remote Desktop replacement).
.DESCRIPTION
    Installs Microsoft Windows App via WinGet with robust error handling, exit code checking,
    and user/system context package verification.
    Optimized for Datto RMM (CentraStage), Intune, SCCM, and SYSTEM account execution via powershell.exe.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Datto RMM component variables are exposed as environment variables
# We need to check and see if they exist, if not set default values.
if ( -not ([string]::IsNullOrWhiteSpace($env:ShortcutName)))
{
  $WindowsShortcutName = "$env:ShortcutName"
} else
{
  $WindowsShortcutName = 'Windows App'
}
if ( -not ([string]::IsNullOrWhiteSpace($env:CompanyName)))
{
  $CompanyName = "$env:CompanyName"
} else
{
  $CompanyName = 'MyCompany'
}

# Microsoft Store Product ID for Windows App
$WingetAppId = '9N1F85V9T8BN'
$AppxIdentity = 'MicrosoftCorporationII.Windows365'

function Get-WinGetPath
{
  # 1. Check if winget is directly available in PATH (suppress errors in RMM logs)
  $cmd = Get-Command winget -ErrorAction SilentlyContinue
  if ($cmd)
  {
    return $cmd.Source
  }

  # 2. Check standard user execution alias path (if running in user context)
  if ($env:LOCALAPPDATA)
  {
    $userAliasPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path $userAliasPath)
    {
      return $userAliasPath
    }
  }

  # 3. Check ProgramFiles AppInstaller location (essential for SYSTEM / Datto RMM context)
  $appInstallerDir = Join-Path $env:ProgramFiles "WindowsApps"
  if (Test-Path $appInstallerDir)
  {
    $installerFolders = Get-ChildItem -Path $appInstallerDir -Filter "Microsoft.DesktopAppInstaller*" -ErrorAction SilentlyContinue
    foreach ($folder in $installerFolders)
    {
      $wingetExe = Join-Path $folder.FullName "winget.exe"
      if (Test-Path $wingetExe)
      {
        return $wingetExe
      }
    }
  }

  return $null
}

function Install-WinGetBootstrap
{
  Write-Host "WinGet binary not found. Attempting automatic WinGet (App Installer) bootstrap..."
  try
  {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $tempDir = Join-Path $env:TEMP "WinGetBootstrap"
    if (-not (Test-Path $tempDir))
    { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null 
    }
        
    $msixPath = Join-Path $tempDir "AppInstaller.msixbundle"
    Write-Host "Downloading latest AppInstaller bundle from Microsoft..."
    Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile $msixPath -UseBasicParsing
        
    Write-Host "Installing AppInstaller bundle..."
    Add-AppxPackage -Path $msixPath -ErrorAction Stop
    Write-Host "WinGet bootstrapped successfully."
        
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
  } catch
  {
    Write-Warning "Auto-bootstrap attempt failed: $_"
  }
}

function Invoke-DesktopShortcut
{
  $WindowsAppDesktopShortcutLocation = "C:\Users\Public\Desktop\$WindowsShortcutName.lnk"

  if(Test-Path -Path "$WindowsAppDesktopShortcutLocation")
  {
    Write-Host "INFO: Shortcut already exists. Deleting and recreating it."
    Remove-Item -Path "$WindowsAppDesktopShortcutLocation" -Force
  }

  # Source - https://stackoverflow.com/a/38372136
  # Posted by Grace Feng, modified by community. See post 'Timeline' for change history
  # Retrieved 2026-08-20, License - CC BY-SA 3.0

  $AppUserModelId = 'MicrosoftCorporationII.Windows365_8wekyb3d8bbwe!Windows365'
  $ShortcutFile = "$WindowsAppDesktopShortcutLocation"
  $IconDestination = "C:\ProgramData\$CompanyName\icons\windows-app.ico"

  if (-not (Test-Path $IconDestination))
  {
    New-Item -ItemType Directory -Path (Split-Path $IconDestination) -Force | Out-Null
    Copy-Item -Path ".\windows-app.ico" -Destination $IconDestination -Force
  }

  $WScriptShell = New-Object -ComObject WScript.Shell
  $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
  $Shortcut.TargetPath = "$env:windir\explorer.exe"
  $Shortcut.Arguments = "shell:AppsFolder\$AppUserModelId"
  $Shortcut.IconLocation = $IconDestination
  $Shortcut.Save()

  Write-Host "SUCCESS: Created desktop shortcut for the Windows App."

}

# --- Step 1: Locate WinGet ---
Write-Host "Locating WinGet..."
$wingetPath = Get-WinGetPath

if (-not $wingetPath)
{
  # Attempt auto-bootstrap if missing
  Install-WinGetBootstrap
  $wingetPath = Get-WinGetPath
}

if (-not $wingetPath)
{
  Write-Error "WinGet (App Installer) is not installed or could not be located on this system."
  Write-Error "Please ensure App Installer is installed on the target machine."
  exit 1
}

Write-Host "WinGet executable found at: $wingetPath"

# --- Step 2: Execute Silent Installation ---
Write-Host "Starting silent installation of Windows App (ID: $WingetAppId)..."

$wingetArgs = @(
  "install",
  "--id", "$WingetAppId",
  "--source", "msstore",
  "--exact",
  "--scope", "machine",
  "--silent",
  "--accept-package-agreements",
  "--accept-source-agreements",
  "--disable-interactivity"
)

try
{
  # Execute WinGet binary with process exit code monitoring
  $process = Start-Process -FilePath $wingetPath -ArgumentList $wingetArgs -Wait -NoNewWindow -PassThru
  $exitCode = $process.ExitCode
} catch
{
  Write-Error "An error occurred while launching WinGet: $_"
  exit 1
}

# WinGet exit codes: 0 = Success, 0x8A15000B (-1978335189) = Already installed / no update required
if ($exitCode -ne 0 -and $exitCode -ne -1978335189)
{
  $hexCode = "0x{0:X8}" -f [uint32]$exitCode
  Write-Error "WinGet failed with exit code $exitCode ($hexCode)."
  exit 1
}

Write-Host "WinGet process completed successfully (Exit Code: $exitCode)."

# --- Step 3: Verification ---
Write-Host "Verifying installation of package '$AppxIdentity'..."

$installedPackage = $null

# Check current user context first
try
{
  $installedPackage = Get-AppxPackage -Name "$AppxIdentity" -ErrorAction SilentlyContinue
} catch
{
  # Ignore per-user query failures
}

# If not found in user context, try -AllUsers (requires elevation / SYSTEM context)
if (-not $installedPackage)
{
  try
  {
    $installedPackage = Get-AppxPackage -AllUsers -Name "$AppxIdentity" -ErrorAction SilentlyContinue
  } catch
  {
    # Catch Access Denied if non-elevated
  }
}

if ($installedPackage)
{
  $pkgName = if ($installedPackage.PackageFullName)
  { $installedPackage.PackageFullName 
  } else
  { $AppxIdentity 
  }
  Write-Host "SUCCESS: Windows App ($pkgName) is installed."
  Invoke-DesktopShortcut
  exit 0
} else
{
  Write-Error "FAILURE: WinGet reported success, but package '$AppxIdentity' was not detected in AppxPackage list."
  exit 1
}
exit 1
