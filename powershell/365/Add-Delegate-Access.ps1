<#
.SYNOPSIS
    Script to set up a delegate for a mailbox in 365
.DESCRIPTION
    Script to set up a delegate for a mailbox in 365
.PARAMETER User
    [String] user's email address
.EXAMPLE
 Delegate-Access -User joe@blow.com  
.NOTES
    Written by Scott Barning
    Date: 1/11/2024
#>

param (
    [Parameter(Mandatory)][string]$User
      )

# The mailboxes we'll be applying delegate access to.
$mailboxes = @("user@domain.com","user2@domain.com")

#Check to make sure that we have a user account to apply this to.
if([string]::IsNullOrWhiteSpace($User))
{
    Read-Host "You must enter a user account to delegate to: "; EXIT
}
try {
    Import-Module ExchangeOnlineManagement
}
catch {
    Write-Output "Exchange online module not installed, installing..." | Out-Null
    Install-Module ExchangeOnlineManagement
    Write-Output "Exchange online module installed successfully!"
}
finally {
    Connect-ExchangeOnline
}

foreach ($mailbox in $mailboxes) {
    foreach ($user in $users) {
        try {
            Write-Host "Adding Full Access Rights to $user"
            Add-MailboxPermission -Identity $mailbox -User $user -AccessRights FullAccess
            Write-Host "Adding Send As Rights to $user"
            Add-RecipientPermission -Identity $mailbox -Trustee $user -AccessRights SendAs -Confirm:$false
        }
        catch {
            Write-Output "$_"
        }

    }
}
