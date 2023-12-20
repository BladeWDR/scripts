<#
.SYNOPSIS
    Script to set up a delegate for a mailbox in 365
.DESCRIPTION
    Script to set up a delegate for a mailbox in 365
.PARAMETER User
    [String] user's email address
.PARAMETER Delegate 
    [String] the email address of the user you're delegating access to.
.PARAMETER AccessLevel
    [string] the access level of the delegate. Allowed values: fullaccess (gives read and manage permissions.) or sendas (which allows user to send messages as the other person.)
.EXAMPLE
    .
.NOTES
    Written by Scott Barning
    Date: 12/19/2023

#>

param (
    [string]$User
    [string]$Delegate
    [string]$AccessLevel
      )


function Enable-Delegate {

    $confirmation = Read-Host "You are adding $AccessLevel rights for $User`'s mailbox for $Delegate, do you wish to continue? (y/n)"

    if ($confirmation -eq 'y'){

        #Enable the delegate access.
        Add-MailboxPermission -Identity $User -User $Delegate -AccessRights $converted
        Write-Host "Added mailbox permissions to $Delegate."

    }



}


function Disable-Delegate {

    $confirmation = Read-Host "You are removing $AccessLevel rights for $User`'s mailbox for $Delegate, do you wish to continue? (y/n)"

    if ($confirmation -eq 'y'){

        #Disable the delegate access.
        Remove-MailboxPermission -Identity $User -User $Delegate -AccessRights $converted
        Write-Host "Removed mailbox permissions from $Delegate."

    }


}

#add try-catch loop here to make sure that Exchange Online module is installed, and if not, try to install it, then connect again.
try {

    Import-Module -Name ExchangeOnlineManagement | Out-Null
    Clear-Host
    Write-Host "Module imported"
}
catch {
    Write-Host "ExhangeOnlineManagement module does not seem to be installed."
    Write-Host "Attempting to install ExchangeOnlineManagement"
    Install-Module -Name ExchangeOnlineManagement -allowClobber
    Import-Module -Name ExchangeOnlineManagement | Out-Null
    Write-Host "Module imported"
}

Connect-ExchangeOnline
#convert $AccessLevel into one of the -AccessRights mappings
if ($AccessRights.ToLower() -eq "fullaccess"){

    $converted[] = 'fullaccess'
}
elseif ($AccessRights.ToLower() -eq "sendas") {

    $converted[] = 'fullaccess','sendas'

}
else {

    Write-Host "Invalid AccessRights Parameter. Valid values are fullaccess or sendas."
}

Enable-Delegate
