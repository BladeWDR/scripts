<# Written By: Scott Barning
Simple script to copy files / folders from one location to another with notifications via the BurnToast powershell module.
https://github.com/Windos/BurntToast
#>
<# 
    .SYNOPSIS
        https://github.com/Windos/BurntToast
        Simple script to copy files / folders from one location to another with notifications via the BurnToast powershell module.
    .PARAMETER SourceFolder
        [String]
    .PARAMETER DestFolder
        [String]
    .EXAMPLE
        Copy-WithNotification -SourceFolder C:\blah -DestFolder D:\blah
    .NOTES
        Written by: Scott Barning
        Date: 1/4/2024
#>

param (
    [string]$SourceFolder,
    [string]$DestFolder
      )

#Make sure we have the burnttoast module available.
try {
Import-Module -Name BurntToast | Out-Null
Write-Output "Module Imported."
}
catch {
    Write-Output "BurntToast module is not installed, installing."
    Install-Module -name BurntToast -allowClobber
    Import-Module -Name BurntToast | Out-Null
    Write-Output "Module Imported."
}

try {
Copy-Item -Path "$SourceFolder\*" -Destination $DestFolder -Recurse -ErrorAction stop 
New-BurntToastNotification -Text "File copy completed succesfully."
}
catch {
    New-BurntToastNotification -Text "Error with file copy, please contact IT."
}
