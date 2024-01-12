function Uninstall-TeamsClassic($TeamsPath) {
    try {
        $process = Start-Process -FilePath "$TeamsPath\Update.exe" -ArgumentList "--uninstall /s" -PassThru -Wait -ErrorAction STOP

            if ($process.ExitCode -ne 0) {
                Write-Error "Uninstallation failed with exit code $($process.ExitCode)."
            }
    }
    catch {
        Write-Error $_.Exception.Message
    }
}

function Install-Winget() {

    # Need to set the script to use TLS 1.2 for the web request.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    $URL = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        $URL = (Invoke-WebRequest -Uri $URL -UseBasicParsing).Content | ConvertFrom-Json |
        Select-Object -ExpandProperty "assets" |
        Where-Object "browser_download_url" -Match '.msixbundle' |
        Select-Object -ExpandProperty "browser_download_url"

# download
        Invoke-WebRequest -Uri $URL -OutFile "Setup.msix" -UseBasicParsing

# install
        Add-AppxPackage -Path "Setup.msix"

# delete file
        Remove-Item "Setup.msix"

}

# Remove Teams Machine-Wide Installer
Write-Host "Removing Teams Machine-wide Installer"
$MachineWide = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq "Teams Machine-Wide Installer" }

if ($MachineWide) {
    $MachineWide.Uninstall()
}
else {
    Write-Host "Teams Machine-Wide Installer not found"
}

# Get all Users
$AllUsers = Get-ChildItem -Path "$($ENV:SystemDrive)\Users"

# Process all Users
foreach ($User in $AllUsers) {
    Write-Host "Processing user: $($User.Name)"

# Locate installation folder
        $localAppData = "$($ENV:SystemDrive)\Users\$($User.Name)\AppData\Local\Microsoft\Teams"
        $programData = "$($env:ProgramData)\$($User.Name)\Microsoft\Teams"

        if (Test-Path "$localAppData\Current\Teams.exe") {
            Write-Host "  Uninstall Teams for user $($User.Name)"
                Uninstall-TeamsClassic -TeamsPath $localAppData
        }
    elseif (Test-Path "$programData\Current\Teams.exe") {
        Write-Host "  Uninstall Teams for user $($User.Name)"
            Uninstall-TeamsClassic -TeamsPath $programData
    }
        else {
            Write-Host "  Teams installation not found for user $($User.Name)"
        }
}

# Remove old Teams folders and icons
$TeamsFolder_old = "$($ENV:SystemDrive)\Users\*\AppData\Local\Microsoft\Teams"
$TeamsIcon_old = "$($ENV:SystemDrive)\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Teams*.lnk"
Get-Item $TeamsFolder_old | Remove-Item -Force -Recurse
Get-Item $TeamsIcon_old | Remove-Item -Force -Recurse

# Install WinGet
Install-Winget

try {
    winget install Microsoft.Teams
}
catch {
   Write-Host -foregroundcolor Red "An error occurred: $_" 
   $_.ScriptStackTrace
}
