###################################################
# Get-Delegations.ps1 myadminuser@domain.onmicrosoft.com
# Gets all 365 mailboxes who have delegated access to their mailbox.
# Includes both User and Shared mailbox types.
###################################################

param(
    [Parameter()][string]$defaultValue
)
$outputFile="$env:userprofile\Downloads\delegation.csv"

if([string]::IsNullOrWhiteSpace($defaultValue))
{
    Read-Host "You must enter an account with admin rights"; EXIT
}
try {
    Import-Module ExchangeOnlineManagement | Out-Null
}
catch {
    Write-Host 'Installing Exchange Online module...'
    Install-Module ExchangeOnlineManagement -AllowClobber
    Import-Module ExchangeOnlineManagement | Out-Null
    Clear-Host
}
finally {
    Connect-ExchangeOnline -UserPrincipalName $defaultValue
}
# Get list of all mailboxes, shared and actual
$mailboxPermissions = @()
$delegates = @()

# Get all mailboxes
$mailboxes = Get-Mailbox -ResultSize Unlimited

# Iterate over mailboxes and check for delegations
foreach ($mailbox in $mailboxes) {
    # Get mailbox delegates
    write-host "Checking $mailbox"
    $delegates = Get-MailboxPermission -Identity $mailbox.DistinguishedName  | Where-Object { $_.IsInherited -eq $false -and $_.User -ne "NT AUTHORITY\SELF" }
# If delegates exist, add them to the array
if ($delegates) {
    foreach ($delegate in $delegates) {
        $mailboxPermissions += [PSCustomObject]@{
            "Mailbox" = $mailbox.UserPrincipalName
                "Delegate" = $delegate.User
                "Access Rights" = $delegate.AccessRights
        }
    }
}
}
Clear-Host
# export to csv
$mailboxPermissions | Export-Csv -Path $outputFile -NoTypeInformation
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXX"
Write-Host "Exported to $outputFile"
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXX"
