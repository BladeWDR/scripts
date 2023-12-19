<#
.SYNOPSIS
    Script to change the MFA state of a user in Office 365.
.DESCRIPTION
    .
.PARAMETER State
    [String] true enables, false disables. Default is false.
.PARAMETER UserPrincipalName 
    [String] Users name in the format username@example.com
.EXAMPLE
    Enable-Disable-MFA.ps1 -State true -UserPrincipalName user@example.com
.NOTES
    Written by Scott Barning
    Date: 12/19/2023

#>

param (
    [string]$State=false,
    [string]$UserPrincipalName
      )

function Change-MFA-State {

    if($State -eq $false){

        Get-MsolUser -UserPrincipalName $UserPrincipalName | Set-MsolUser -StrongAuthenticationRequirements @()

    }
    elseif($State -eq $true){

        # Create the StrongAuthenticationRequirement Object
        $sa = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
        $sa.RelyingParty = "*"
        $sa.State = "Enabled"
        $sar = @($sa)
        
        # Enable MFA for the user
        Set-MsolUser -UserPrincipalName $UserPrincipalName -StrongAuthenticationRequirements $sar        

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

#set variables
# $UserPrincipalName = Read-Host -Prompt 'Please enter the user to change the MFA status for in the format user@example.com: ' 
# $input= Read-Host -Prompt "Enter true or false depending on what operation you wish to perform (true=enable, false=disable [default: disable]): "
$State= [System.Convert]::ToBoolean($input)

#call the function
Change-MFA-State

#Remove the MSOnline session
[Microsoft.Online.Administration.Automation.ConnectMsolService]::ClearUserSessionState()
