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

#choco install 7zip adobereader google-chrome-x64 firefox vscode powershell-core git neovim mingw make
choco install git neovim mingw make

#reload env yet AGAIN so i can use git.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

# Install VS Code extensions

code --install-extension ms-vscode-remote.remote-containers

code --install-extension ms-vscode-remote.remote-ssh

Install-NvimConfig