# Remove-Groups.ps1 John Smith
# Remove-Groups.ps1 jsmith@domain.com

param(
[Parameter(Mandatory)][string]$name
)
if([string]::IsNullOrWhiteSpace($name))
{
    Read-Host "Enter the user's name or email address"; EXIT
}

try {
    Import-Module ExchangeOnlineManagement
}
catch {
    Write-Host "EOM module not installed, installing..."
    Install-Module ExchangeOnlineManagement -AllowClobber | Out-Null
    Write-Host "Installed successfully."
}

$user = Get-Mailbox -Identity $name | Select-Object -ExpandProperty PrimarySmtpAddress
$distributionLists = Get-DistributionGroup | Select-Object -ExpandProperty Name
$office365Groups = Get-UnifiedGroup | Select-Object -ExpandProperty Name

foreach ($list in $distributionLists) {
    $distlistmembers = Get-DistributionGroupMember -Identity $list | Select-Object -ExpandProperty PrimarySmtpAddress
    
        if( $user -in $distlistmembers) {
            Remove-DistributionGroupMember -Identity $list -Member $user -Confirm:$false
            Write-Host "The user $user has been removed from the distribution list $list"
        }
}


foreach ($group in $office365Groups) {
    $o365groupmembers = Get-UnifiedGroupLinks -Identity $group -LinkType Members | Select-Object -ExpandProperty PrimarySmtpAddress
        if( $user -in $o365groupmembers) {
            try {
                Remove-UnifiedGroupLinks -Identity $group -LinkType Owners -Links $user -Confirm:$false
            }
            catch {
                Write-Host "Error removing user as an owner of $group. It's likely that they're the only owner of the group."
            }
            Remove-UnifiedGroupLinks -Identity $group -LinkType Members -Links $user -Confirm:$false
            Write-Host "The user $($user) has been removed from the Office 365 group $group"
    }
}
