function Install-WinUtilChoco
{
    Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) -ErrorAction Stop
    powershell choco feature enable -n allowGlobalConfirmation
}

function Install-Apps
{
    # Install programs via choco
    choco install 7zip firefox -y
    # Installs Open Shell without Classic Explorer.
    choco install open-shell -y --install-arguments="'/qn ADDLOCAL=StartMenu'"
}

function Disable-RestartApps
{
    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $valueName = "RestartApps"

    if (-not (Test-Path -Path "$regPath"))
    {
        New-Item -Path $regPath -Force
    }

    if ($null -eq (Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue))
    {
        New-ItemProperty -Path $regPath -Name $valueName -PropertyType Dword -Force -Value 0
    } else
    {
        Set-ItemProperty -Path $regPath -Name $valueName -Value 0
    }
}

# Install chocolatey
Install-WinUtilChoco

# Reload environment so we can use choco commands.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

Install-Apps

Disable-RestartApps

Read-Host "Installs complete. Press Enter to continue..."
