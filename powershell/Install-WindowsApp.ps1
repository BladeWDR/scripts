<#
.SYNOPSIS
    Automated silent installer for Microsoft Windows App via direct MSIX package download.
.DESCRIPTION
    Downloads and installs the official Microsoft Windows App MSIX package directly,
    bypassing WinGet and App Store dependencies for 100% reliable execution under
    Datto RMM (CentraStage), SYSTEM account, Intune, and SCCM.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$false)]
  [string]$MsixUrl = "https://go.microsoft.com/fwlink/?linkid=2262633"
)

$ErrorActionPreference = 'Stop'

# Auto-relaunch in 64-bit PowerShell process if executing in 32-bit (WOW64) context (e.g. Datto RMM / CentraStage)
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess)
{
  $sysNativePowerShell = Join-Path $env:SystemRoot "SysNative\WindowsPowerShell\v1.0\powershell.exe"
  if (Test-Path $sysNativePowerShell)
  {
    Write-Host "Switching execution from 32-bit (WOW64) to 64-bit PowerShell process..."
    $scriptPath = if ($PSCommandPath)
    { $PSCommandPath 
    } else
    { $MyInvocation.MyCommand.Path 
    }
    if ($scriptPath)
    {
      & $sysNativePowerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @args
      exit $LASTEXITCODE
    }
  }
}

if (-not [string]::IsNullOrWhiteSpace($env:MsixUrl))
{
  $MsixUrl = $env:MsixUrl
}

if (-not [string]::IsNullOrWhiteSpace($env:ShortcutName))
{
  $WindowsShortcutName = "$env:ShortcutName"
} else
{
  $WindowsShortcutName = 'Windows App'
}

if (-not [string]::IsNullOrWhiteSpace($env:CompanyName))
{
  $CompanyName = "$env:CompanyName"
} else
{
  $WindowsShortcutName = 'MyCompany'
}


$AppxIdentity = 'MicrosoftCorporationII.Windows365'
$AppUserModelId = 'MicrosoftCorporationII.Windows365_8wekyb3d8bbwe!Windows365'

function Invoke-DesktopShortcut
{
  $WindowsAppDesktopShortcutLocation = "C:\Users\Public\Desktop\$WindowsShortcutName.lnk"

  try
  {
    if (Test-Path -Path "$WindowsAppDesktopShortcutLocation")
    {
      Write-Host "INFO: Shortcut already exists. Deleting and recreating it."
      Remove-Item -Path "$WindowsAppDesktopShortcutLocation" -Force
    }

    $ShortcutFile = "$WindowsAppDesktopShortcutLocation"
    $IconDestination = "C:\ProgramData\$CompanyName\icons\windows-app.ico"

    if (-not (Test-Path $IconDestination))
    {
      New-Item -ItemType Directory -Path (Split-Path $IconDestination) -Force | Out-Null
      if (Test-Path ".\windows-app.ico")
      {
        Copy-Item -Path ".\windows-app.ico" -Destination $IconDestination -Force
      }
    }

    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
    $Shortcut.TargetPath = "$env:windir\explorer.exe"
    $Shortcut.Arguments = "shell:AppsFolder\$AppUserModelId"
    if (Test-Path $IconDestination)
    {
      $Shortcut.IconLocation = $IconDestination
    }
    $Shortcut.Save()

    Write-Host "SUCCESS: Created desktop shortcut for Windows App."
  } catch
  {
    Write-Warning "Desktop shortcut creation note: $_"
  }
}

# --- Step 1: Download Direct MSIX Package ---
Write-Host "Downloading Microsoft Windows App MSIX package from: $MsixUrl"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tempDir = Join-Path $env:TEMP "WindowsAppInstall"
if (-not (Test-Path $tempDir))
{
  New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

$msixPath = Join-Path $tempDir "WindowsApp.msix"

try
{
  if (Test-Path $msixPath)
  {
    Remove-Item -Path $msixPath -Force -ErrorAction SilentlyContinue
  }

  $webClient = New-Object System.Net.WebClient
  $webClient.DownloadFile($MsixUrl, $msixPath)
  
  $fileSize = (Get-Item $msixPath).Length
  Write-Host "Downloaded MSIX package successfully ($fileSize bytes)."
} catch
{
  Write-Error "Failed to download Windows App MSIX package: $_"
  exit 1
}

# --- Step 2: Install MSIX Package ---
Write-Host "Installing Windows App MSIX package..."

$installed = $false

# 1. Provision package machine-wide for all users (essential for SYSTEM / Datto RMM context)
try
{
  Write-Host "Attempting machine-wide provisioned installation (DISM)..."
  Add-AppxProvisionedPackage -Online -PackagePath $msixPath -SkipLicense -ErrorAction Stop | Out-Null
  Write-Host "Provisioned Windows App successfully for all users."
  $installed = $true
} catch
{
  if ("$_" -like "*already installed*" -or "$_" -like "*0x80073CFB*")
  {
    Write-Host "Package is already provisioned machine-wide."
    $installed = $true
  } else
  {
    Write-Host "Provisioned installation note: $_"
  }
}

# 2. Install package for current user / SYSTEM context
try
{
  Write-Host "Installing AppX package for current context..."
  Add-AppxPackage -Path $msixPath -ForceUpdateFromAnyVersion -ErrorAction Stop
  Write-Host "Installed AppX package successfully."
  $installed = $true
} catch
{
  if ("$_" -like "*already installed*" -or "$_" -like "*0x80073CFB*")
  {
    Write-Host "Package is already installed."
    $installed = $true
  } elseif (-not $installed)
  {
    Write-Warning "AppX package install note: $_"
  }
}

# Clean up installer file
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# --- Step 3: Verification & Shortcut ---
Write-Host "Verifying installation of package '$AppxIdentity'..."

$installedPackage = $null

try
{
  $installedPackage = Get-AppxPackage -Name "$AppxIdentity" -ErrorAction SilentlyContinue
} catch
{
}

if (-not $installedPackage)
{
  try
  {
    $installedPackage = Get-AppxPackage -AllUsers -Name "$AppxIdentity" -ErrorAction SilentlyContinue
  } catch
  {
  }
}

if (-not $installedPackage)
{
  try
  {
    $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*Windows365*" -or $_.PackageName -like "*Windows365*" }
    if ($prov)
    { $installedPackage = $prov 
    }
  } catch
  {
  }
}

if ($installedPackage -or $installed)
{
  Write-Host "SUCCESS: Windows App is installed."
  Invoke-DesktopShortcut
  exit 0
} else
{
  Write-Error "FAILURE: Package '$AppxIdentity' installation could not be verified."
  exit 1
}
