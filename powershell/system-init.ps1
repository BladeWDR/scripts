<#
.SYNOPSIS
    Automates Windows system initialization, package installations, and UI tweaks.

.DESCRIPTION
    Configures system time zone, installs essential software via Chocolatey, applies clean 
    Windows UI customizations (Classic Context Menu, Taskbar alignment, disabling telemetry/widgets), 
    and writes detailed log outputs to temporary storage.

.PARAMETER TimeZone
    Specifies the system time zone ID. Defaults to "US Eastern Standard Time".

.PARAMETER TaskbarAlignment
    Sets Windows 11 Taskbar icon alignment. Options: "Left" or "Center". Defaults to "Left".

.PARAMETER Unattended
    Runs non-interactively without asking for user prompt upon completion.

.PARAMETER LogPath
    Path to the log output file. Defaults to "$env:TEMP\system-init.log" which is cleaned 
    automatically by Windows Storage Sense.

.EXAMPLE
    .\system-init.ps1 -TaskbarAlignment Left -Unattended
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$TimeZone = "US Eastern Standard Time",
    [ValidateSet("Left", "Center")][string]$TaskbarAlignment = "Left",
    [switch]$Unattended,
    [string]$LogPath = (Join-Path -Path $env:TEMP -ChildPath "system-init.log")
)

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$script:SuccessCount = 0
$script:ErrorCount = 0
$script:RestartExplorerNeeded = $false

$Banner = @"
  ______   ______ _____ _____ __  __                             
 / ___\ \ / / ___|_   _| ____|  \/  |                            
 \___ \\ V /\___ \ | | |  _| | |\/| |                            
  ___) || |  ___) || | | |___| |  | |                            
 |____/ |_| |____/_|_|_|_____|_|  |_|   ___ ________ _   _  ____ 
 |_ _| \ | |_ _|_   _|_ _|  / \  | |   |_ _|__  /_ _| \ | |/ ___|
  | ||  \| || |  | |  | |  / _ \ | |    | |  / / | ||  \| | |  _ 
  | || |\  || |  | |  | | / ___ \| |___ | | / /_ | || |\  | |_| |
 |___|_| \_|___| |_| |___/_/   \_\_____|___/____|___|_| \_|\____|

"@

# Format header section banners
function Write-Header {
    param([string]$Title)
    $line = "─" * 62
    Write-Host "`n┌$line┐" -ForegroundColor DarkGray
    Write-Host "│  $($Title.PadRight(58))  │" -ForegroundColor Yellow
    Write-Host "└$line┘" -ForegroundColor DarkGray
}

# Writes log entries to both console (with modern status icons) and log file ($env:TEMP)
function Write-Log {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        
        [Parameter(Position = 1)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "STEP")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    $logDir = Split-Path -Path $LogPath -Parent
    if ($logDir -and -not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue

    $symbol, $color = switch ($Level) {
        "SUCCESS" { "[✔]", "Green";  $script:SuccessCount++ }
        "WARN"    { "[!]", "Yellow" }
        "ERROR"   { "[✖]", "Red";    $script:ErrorCount++ }
        "STEP"    { "[➜]", "Cyan" }
        default   { "[ℹ]", "DarkCyan" }
    }

    Write-Host "$symbol " -ForegroundColor $color -NoNewline
    Write-Host $Message
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$PropertyType = "DWord"
    )
    $changed = $false
    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
        $changed = $true
    }
    
    $currentVal = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($null -eq $currentVal -or $currentVal -ne $Value) {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $PropertyType -Force
        $changed = $true
    }

    if ($changed) {
        $script:RestartExplorerNeeded = $true
    }
    return $changed
}

function Set-TaskbarAlignment {
    param([ValidateSet("Left", "Center")][string]$Justify)
    try {
        $val = if ($Justify -eq "Left") { 0 } else { 1 }
        $changed = Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value $val
        if ($changed) {
            Write-Log "Taskbar alignment set to $Justify." -Level SUCCESS
        } else {
            Write-Log "Taskbar alignment already set to $Justify." -Level SUCCESS
        }
    } catch {
        Write-Log "Failed to set taskbar alignment: $_" -Level ERROR
    }
}

function Disable-Widgets {
    try {
        $changed = Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0
        if ($changed) {
            Write-Log "Disabled Widgets / News & Interests." -Level SUCCESS
        } else {
            Write-Log "Widgets / News & Interests already disabled." -Level SUCCESS
        }
    } catch {
        Write-Log "Failed to disable Widgets: $_" -Level ERROR
    }
}

function Disable-Searchbox {
    try {
        $changed = Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchBoxTaskbarMode" -Value 0
        if ($changed) {
            Write-Log "Disabled Search Box on Taskbar." -Level SUCCESS
        } else {
            Write-Log "Search Box on Taskbar already disabled." -Level SUCCESS
        }
    } catch {
        Write-Log "Failed to disable Search Box: $_" -Level ERROR
    }
}

function Disable-TaskView {
    try {
        $changed = Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
        if ($changed) {
            Write-Log "Disabled Task View button." -Level SUCCESS
        } else {
            Write-Log "Task View button already disabled." -Level SUCCESS
        }
    } catch {
        Write-Log "Failed to disable Task View: $_" -Level ERROR
    }
}

function Disable-Win11ContextMenu {
    try {
        $regPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        $changed = $false
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
            Set-ItemProperty -Path $regPath -Name "(default)" -Value "" | Out-Null
            $changed = $true
        } else {
            $currentVal = (Get-ItemProperty -Path $regPath -Name "(default)" -ErrorAction SilentlyContinue)."(default)"
            if ($null -eq $currentVal -or $currentVal -ne "") {
                Set-ItemProperty -Path $regPath -Name "(default)" -Value "" | Out-Null
                $changed = $true
            }
        }

        if ($changed) {
            $script:RestartExplorerNeeded = $true
            Write-Log "Disabled Windows 11 modern context menu (restored Classic Context Menu)." -Level SUCCESS
        } else {
            Write-Log "Classic Context Menu already enabled." -Level SUCCESS
        }
    } catch {
        Write-Log "Failed to restore Classic Context Menu: $_" -Level ERROR
    }
}

function Disable-DeviceCompanionApps {
    try {
        $changed = Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -Value 1
        if ($changed) {
            Write-Log "Disabled automatic device companion app downloads." -Level SUCCESS
        } else {
            Write-Log "Automatic device companion app downloads already disabled." -Level SUCCESS
        }
    } catch {
        Write-Log "Failed to disable device companion apps: $_" -Level ERROR
    }
}

function Disable-RestartApps {
    try {
        $changed = Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "RestartApps" -Value 0
        if ($changed) {
            Write-Log "Disabled Restart Apps on reboot." -Level SUCCESS
        } else {
            Write-Log "Restart Apps on reboot already disabled." -Level SUCCESS
        }
    } catch {
        Write-Log "Failed to disable Restart Apps: $_" -Level ERROR
    }
}

function Install-WinUtilChoco {
    Write-Log "Checking Chocolatey package manager..." -Level STEP
    if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
        try {
            Write-Log "Installing Chocolatey package manager..." -Level INFO
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Set-ExecutionPolicy Bypass -Scope Process -Force
            Invoke-Expression (Invoke-RestMethod -Uri 'https://community.chocolatey.org/install.ps1')
            
            # Reload environment Path
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            choco feature enable -n allowGlobalConfirmation
            Write-Log "Chocolatey installed successfully." -Level SUCCESS
        } catch {
            Write-Log "Failed to install Chocolatey: $_" -Level ERROR
        }
    } else {
        Write-Log "Chocolatey is already installed." -Level SUCCESS
    }
}

function Install-Apps {
    Write-Log "Installing core applications (7zip, firefox, sumatrapdf, open-shell)..." -Level STEP
    try {
        choco install 7zip firefox sumatrapdf -y
        choco install open-shell -y --install-arguments="'/qn ADDLOCAL=StartMenu'"
        Write-Log "Core applications installed successfully." -Level SUCCESS
    } catch {
        Write-Log "One or more application installs failed: $_" -Level ERROR
    }

    $OpenShellPath = "$env:ProgramFiles\Open-Shell\StartMenu.exe"
    if (Test-Path $OpenShellPath) {
        try {
            Write-Log "Configuring Open-Shell update scheduled task..." -Level INFO
            $Action = New-ScheduledTaskAction -Execute $OpenShellPath -Argument "-upgrade -silent"
            $Trigger = New-ScheduledTaskTrigger -AtStartup
            $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

            Register-ScheduledTask `
                -TaskName "Open-Shell OS upgrade check" `
                -Action $Action `
                -Trigger $Trigger `
                -Principal $Principal `
                -Force | Out-Null
            Write-Log "Scheduled task for Open-Shell registered." -Level SUCCESS
        } catch {
            Write-Log "Failed to configure Open-Shell scheduled task: $_" -Level ERROR
        }
    }
}

# --- Execution Flow ---
Clear-Host
Write-Host $Banner -ForegroundColor Yellow
Write-Log "Log file initialized at $LogPath" -Level INFO

Write-Header "1. System Time & Package Manager"
try {
    Write-Log "Setting time zone to '$TimeZone'..." -Level STEP
    Set-TimeZone -Id $TimeZone -ErrorAction Stop
    Write-Log "Time zone set to '$TimeZone'." -Level SUCCESS
} catch {
    Write-Log "Could not set time zone: $_" -Level WARN
}

Install-WinUtilChoco

Write-Header "2. Software Installation"
Install-Apps

Write-Header "3. Windows Customizations & UI Tweaks"
Disable-RestartApps
Set-TaskbarAlignment -Justify $TaskbarAlignment
Disable-Widgets
Disable-Searchbox
Disable-TaskView
Disable-Win11ContextMenu
Disable-DeviceCompanionApps

Write-Header "4. Finalizing Setup"
if ($script:RestartExplorerNeeded) {
    try {
        Write-Log "Restarting Windows Explorer to apply UI tweaks..." -Level STEP
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Write-Log "Explorer restarted successfully." -Level SUCCESS
    } catch {
        Write-Log "Could not restart Explorer: $_" -Level WARN
    }
} else {
    Write-Log "No Explorer UI changes were made. Skipping Explorer restart." -Level INFO
}

$Stopwatch.Stop()
$elapsed = $Stopwatch.Elapsed.ToString("mm\:ss")
$statusSummary = if ($script:ErrorCount -eq 0) { "SUCCESS" } else { "COMPLETED WITH ERRORS" }
$summaryColor = if ($script:ErrorCount -eq 0) { "Green" } else { "Yellow" }

Write-Host @"

┌────────────────────────────────────────────────────────────┐
│                    EXECUTION SUMMARY                       │
├───────────────────────────────┬────────────────────────────┤
│ Status                        │ $($statusSummary.PadRight(26)) │
│ Succeeded Tasks               │ $($script:SuccessCount.ToString().PadRight(26)) │
│ Failed Tasks                  │ $($script:ErrorCount.ToString().PadRight(26)) │
│ Total Duration                │ $($elapsed.PadRight(26)) │
│ Log Location                  │ Temp ($env:TEMP)           │
└───────────────────────────────┴────────────────────────────┘
"@ -ForegroundColor $summaryColor

Write-Log "System initialization completed in $elapsed with $script:ErrorCount error(s)." -Level INFO

if (-not $Unattended) {
    Write-Host ""
    Read-Host "Installs complete. Press Enter to continue..."
}
