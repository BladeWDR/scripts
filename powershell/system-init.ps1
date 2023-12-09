$neovimConfigDir = "C:\Users\$env:USERPROFILE\nvim\"
$gitDir = "C:\git\neovim"
$patternToSkip = ".git*"


function Install-WinUtilChoco {

        Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) -ErrorAction Stop
        powershell choco feature enable -n allowGlobalConfirmation

}

function Install-NvimConfig {
    
    Write-Host "Cloning init.lua repository..."

    git clone https://github.com/BladeWDR/init.lua.git $gitDir

    if (Test-Path -Path $gitDir -PathType Container) {
        # Create the destination folder if it doesn't exist
        if (-not (Test-Path -Path $neovimConfigDir -PathType Container)) {
            New-Item -ItemType Directory -Path $neovimConfigDir | Out-Null
        }

        # Get all files and folders in the source folder
        $items = Get-ChildItem -Path $gitDir

        # Iterate through each file and folder
        foreach ($item in $items) {
            if ($item.Name -notlike $patternToSkip) {
            # Create the destination path for the file or folder
            $destinationPath = Join-Path -Path $neovimConfigDir -ChildPath $item.Name

            # Copy the file or folder to the destination
            New-Item -ItemType SymbolicLink -Path $destinationPath -Target $item.FullName
            }
        }

        Write-Host "Files and folders copied successfully."
    } else {
        Write-Host "Source folder does not exist."
    }



}

# Install chocolatey
Install-WinUtilChoco

# Reload environment so we can use choco commands.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

# Install programs via choco

choco install 7zip adobereader google-chrome-x64 firefox vscode powershell-core docker-desktop

# Install VS Code extensions

code --install-extension ms-vscode-remote.remote-containers

code --install-extension ms-vscode-remote.remote-ssh

Install-NvimConfig