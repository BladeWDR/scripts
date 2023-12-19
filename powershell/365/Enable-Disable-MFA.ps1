<#
.SYNOPSIS
    Script to change the MFA state of a user in Office 365.
.DESCRIPTION
    .
.PARAMETER State
    [String] true enables, false disables. Default is false.
.PARAMETER UserPrincipalName 
    [String] Users names in the format username@example.com,seconduser@example.com
.EXAMPLE
    Enable-Disable-MFA.ps1 -State true -UserPrincipalName user@example.com
.NOTES
    Written by Scott Barning
    Date: 12/19/2023

#>

param (
    [string]$State='false',
    [string[]]$UserPrincipalName
      )

function Change-MFA-State {


    write-host "the value of `$input is: `$$State" 

    if($State -eq $false){

        foreach ($user in $UserPrincipalName) {
        
        Get-MsolUser -UserPrincipalName $User | Set-MsolUser -StrongAuthenticationRequirements @()
    }

    }
    elseif($State -eq $true){

        foreach ($user in $UserPrincipalName) {
        # Create the StrongAuthenticationRequirement Object
        $sa = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
        $sa.RelyingParty = "*"
        $sa.State = "Enabled"
        $sar = @($sa)
        
        # Enable MFA for the user
        Set-MsolUser -UserPrincipalName $User -StrongAuthenticationRequirements $sar        
        }

    }
    else {

        Write-Host "I'm not sure how you got here, fam."
    }


}


# check if module is installed and import and login
try {
    Import-Module -Name MSOnline | Out-Null
    clear-host
    Write-Host "Module imported"
} 
catch {
    Write-Host "MsolService module is not installed, installing..."
    Install-Module -Name MSOnline -allowClobber
    Import-Module -Name MSOnline | Out-Null
    clear-host
}

Connect-MsolService

[System.Convert]::ToBoolean($State)

#call the function
Change-MFA-State

#Remove the MSOnline session
[Microsoft.Online.Administration.Automation.ConnectMsolService]::ClearUserSessionState()
