function Install-WinUtilChoco {
        Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) -ErrorAction Stop
        powershell choco feature enable -n allowGlobalConfirmation
}

function Install-Apps {
# Install programs via choco
    choco install 7zip adobereader firefox nerd-fonts-CascadiaCode winget
# Use winget to install Chrome since the choco version is constantly broken.
    winget install google.chrome --accept-package-agreements --accept-source-agreements
}

function Edit-Terminal {
# Set the windows terminal default font to the nerd font we downloaded.
    $JsonPath = "$env:localappdata\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
# Check to see if the settings.json file exists.
        if (Test-Path $JsonPath){
#First copy the settings.json file in case we make an ooopsie.
            Copy-Item -Path $JsonPath -Destination "$JsonPath.bak"
            $JsonFile = Get-Content $JsonPath -raw | ConvertFrom-Json
            $JsonFile.profiles.defaults.font.face = "CaskaydiaCove Nerd Font"
            $JsonFile | ConvertTo-Json -depth 32 | Set-Content -Path $JsonPath
        }
}

# Install chocolatey
Install-WinUtilChoco

# Reload environment so we can use choco commands.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

Install-Apps

Edit-Terminal

Read-Host "Installs complete. Press Enter to continue..."
