function Install-NvimConfig {
    $neovimConfigDir = "C:\Users\$env:USERPROFILE\nvim\"
    Write-Host "Cloning init.lua repository..."
    git clone https://github.com/BladeWDR/init.lua.git $neovimConfigDir
}

choco install git neovim mingw make nodejs
# reload env so I can use git.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
Install-NvimConfig
