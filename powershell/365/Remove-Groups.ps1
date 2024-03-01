Import-Module ExchangeOnlineManagement

$users=@()
$userCounter = 0
$distributionLists = Get-DistributionGroup | Select-Object -ExpandProperty Name

$office365Groups = Get-UnifiedGroup | Select-Object -ExpandProperty Name
$mailboxes = @()

foreach ($user in $users) {
    $mailboxes += Get-Mailbox | Where-Object {$_.PrimarySmtpAddress -eq $user}
}

foreach ($list in $distributionLists) {
    $distlistmembers = Get-DistributionGroupMember -Identity $list | Select-Object -ExpandProperty PrimarySmtpAddress
    while ($userCounter -lt $mailboxes.Length){
        if( $mailboxes[$userCounter].PrimarySmtpAddress -in $distlistmembers) {
            Remove-DistributionGroupMember -Identity $list -Member $mailboxes[$userCounter] -Confirm:$false
            Write-Host "The user $($mailboxes[$userCounter]) has been removed from the distribution list $list"
        }
        $userCounter++
    }
    $userCounter = 0
}


foreach ($group in $office365Groups) {
    $o365groupmembers = Get-UnifiedGroupLinks -Identity $group -LinkType Members | Select-Object -ExpandProperty PrimarySmtpAddress
    while ($userCounter -lt $mailboxes.Length){
        if( $mailboxes[$userCounter].PrimarySmtpAddress -in $o365groupmembers) {
            try {
                Remove-UnifiedGroupLinks -Identity $group -LinkType Owners -Links $mailboxes[$userCounter] -Confirm:$false
            }
            catch {
                Write-Host "Error removing user as an owner of $group. It's likely that they're the only owner of the group."
            }
            Remove-UnifiedGroupLinks -Identity $group -LinkType Members -Links $mailboxes[$userCounter] -Confirm:$false
            Write-Host "The user $($mailboxes[$userCounter]) has been removed from the Office 365 group $group"
        }
        $userCounter++
    }
    $userCounter = 0
}
