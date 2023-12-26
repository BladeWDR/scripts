$neovimConfigDir = "C:\Users\$env:USERPROFILE\nvim\"


function Install-WinUtilChoco {

        Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) -ErrorAction Stop
        powershell choco feature enable -n allowGlobalConfirmation

}

function Install-NvimConfig {
    
    Write-Host "Cloning init.lua repository..."

    git clone https://github.com/BladeWDR/init.lua.git $neovimConfigDir



}

# Install chocolatey
Install-WinUtilChoco

# Reload environment so we can use choco commands.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

# Install programs via choco

choco install 7zip adobereader google-chrome-x64 firefox nerd-fonts-CascadiaCode

# Set the windows terminal default font to the nerd font we downloaded.
$JsonPath = "$env:localappdata\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
#First copy the settings.json file in case we make an ooopsie.
Copy-Item -Path $JsonPath -Destination "$JsonPath.bak"
$JsonFile = Get-Content $JsonPath -raw | ConvertFrom-Json
$JsonFile.profiles.defaults.font.face = "CaskaydiaCove Nerd Font"
$JsonFile | ConvertTo-Json -depth 32 | Set-Content -Path $JsonPath



#choco install git neovim mingw make

#reload env yet AGAIN so i can use git.
#$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

# Install VS Code extensions

#code --install-extension ms-vscode-remote.remote-containers

#code --install-extension ms-vscode-remote.remote-ssh

#Install-NvimConfig
