#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$TimeZone = "US Eastern Standard Time",
    [ValidateSet("Left", "Center")][string]$TaskbarAlignment = "Left",
    [switch]$Unattended
)

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

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$PropertyType = "DWord"
    )
    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $PropertyType -Force
}

function Set-TaskbarAlignment {
    param([ValidateSet("Left", "Center")][string]$Justify)
    $val = if ($Justify -eq "Left") { 0 } else { 1 }
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value $val
    Write-Host "Set taskbar alignment to $Justify." -ForegroundColor Cyan
}

function Disable-Widgets {
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0
    Write-Host "Disabled Widgets / News & Interests." -ForegroundColor Cyan
}

function Disable-Searchbox {
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchBoxTaskbarMode" -Value 0
    Write-Host "Disabled Search Box." -ForegroundColor Cyan
}

function Disable-TaskView {
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
    Write-Host "Disabled Task View button." -ForegroundColor Cyan
}

function Disable-Win11ContextMenu {
    $regPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "(default)" -Value "" | Out-Null
    Write-Host "Disabled Windows 11 modern context menu (restored Classic Context Menu)." -ForegroundColor Cyan
}

function Disable-DeviceCompanionApps {
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -Value 1
    Write-Host "Disabled automatic device companion app downloads." -ForegroundColor Cyan
}

function Disable-RestartApps {
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "RestartApps" -Value 0
    Write-Host "Disabled Restart Apps on reboot." -ForegroundColor Cyan
}

function Install-WinUtilChoco {
    Write-Host "Checking Package Manager..." -ForegroundColor Green
    if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey..." -ForegroundColor Green
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression (Invoke-RestMethod -Uri 'https://community.chocolatey.org/install.ps1')
        
        # Reload environment Path
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        choco feature enable -n allowGlobalConfirmation
    } else {
        Write-Host "Chocolatey already installed." -ForegroundColor Green
    }
}

function Install-Apps {
    Write-Host "Starting App Installation..." -ForegroundColor Green

    choco install 7zip firefox sumatrapdf -y
    choco install open-shell -y --install-arguments="'/qn ADDLOCAL=StartMenu'"

    $OpenShellPath = "$env:ProgramFiles\Open-Shell\StartMenu.exe"
    if (Test-Path $OpenShellPath) {
        Write-Host "Configuring Open-Shell update scheduled task..." -ForegroundColor Cyan
        $Action = New-ScheduledTaskAction -Execute $OpenShellPath -Argument "-upgrade -silent"
        $Trigger = New-ScheduledTaskTrigger -AtStartup
        $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

        Register-ScheduledTask `
            -TaskName "Open-Shell OS upgrade check" `
            -Action $Action `
            -Trigger $Trigger `
            -Principal $Principal `
            -Force | Out-Null
    }
}

# Execution Flow
Write-Host $Banner -ForegroundColor Yellow

Write-Host "Setting time zone to $TimeZone" -ForegroundColor Green
Set-TimeZone -Id $TimeZone -ErrorAction SilentlyContinue

Install-WinUtilChoco
Install-Apps

# Apply Windows Customizations
Disable-RestartApps
Set-TaskbarAlignment -Justify $TaskbarAlignment
Disable-Widgets
Disable-Searchbox
Disable-TaskView
Disable-Win11ContextMenu
Disable-DeviceCompanionApps

# Restart Explorer to apply Taskbar/UI/Context menu registry changes immediately
Write-Host "Restarting Explorer to apply UI tweaks..." -ForegroundColor Green
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

if (-not $Unattended) {
    Read-Host "Installs complete. Press Enter to continue..."
}
