function Install-WinUtilChoco {
        Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) -ErrorAction Stop
        powershell choco feature enable -n allowGlobalConfirmation
}

function Install-Apps {
# Install programs via choco
    choco install 7zip firefox -y
# Installs Open Shell without Classic Explorer.
    choco install open-shell -y --install-arguments="'/qn ADDLOCAL=StartMenu'"
}

# function Edit-Terminal {
#     $JsonPath = "$env:localappdata\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
#
# # Check to see if the settings.json file exists.
#     if (Test-Path $JsonPath){
#         $fontProperty = @"
# {
#             "face": "CaskaydiaCove Nerd Font",
#             "size": 12.0
#         },
# "@
# 	$JsonFile = Get-Content $JsonPath -raw
#     if (-not $JsonFile -eq $null) {
# 	$JsonContent = ConvertFrom-Json -InputObject $JsonFile
# 	$JsonContent.profiles.defaults | Add-Member -Name 'font' -Value (ConvertFrom-Json $fontProperty) -MemberType NoteProperty
# 	$JsonContent | ConvertTo-Json -Depth 32 | Set-Content $JsonPath -Force
#     }
#     else {
#         "Json data is null."
#     }
# }
# }
#

# Install chocolatey
Install-WinUtilChoco

# Reload environment so we can use choco commands.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

Install-Apps

#Edit-Terminal

Read-Host "Installs complete. Press Enter to continue..."
