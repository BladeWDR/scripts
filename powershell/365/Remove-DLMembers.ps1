param (
    [Parameter(Mandatory)][string]$user
      )

#Check to make sure that we have a user account to apply this to.
if([string]::IsNullOrWhiteSpace($user))
{
    $user = Read-Host "You must enter a valid user account (e.g. john@johnsmith.com): "; EXIT
}

# Check if the EOM module is installed and install it if needed.
try {
    Import-Module ExchangeOnlineManagement
}
catch {
    Write-Output "Exchange online module not installed, installing..." | Out-Null
    Install-Module ExchangeOnlineManagement
    Write-Output "Exchange online module installed successfully!"
}
finally {
    Connect-ExchangeOnline -ShowBanner:$false
}

$userAlias = (Get-Mailbox -Identity $user).Alias
$userDN = (Get-Mailbox -Identity $user).DistinguishedName

# Get the list of Distribution Groups where this user is a member, then iterate over that list and remove them from all of them.
[array]$DistributionListMember = Get-DistributionGroup | Where-Object { (Get-DistributionGroupMember -Identity $_.DistinguishedName | ForEach-Object { $_.Alias}) -contains $userAlias}

if ($null -ne $DistributionListMember){
Write-Host "Removing user from the following distribution lists: $($DistributionListMember -join ", ")"
$DistributionListMember | ForEach-Object {
    Remove-DistributionGroupMember -Identity $_ -Member $userDN -Confirm:$false
}
}
else {
    Write-Host "User not found in any distribution lists."
}

# Get the list of Office 365 groups where this user is a member.
$Office365GroupsMember = Get-UnifiedGroup | Where-Object { (Get-UnifiedGroupLinks $_.DistinguishedName -LinkType Members | ForEach-Object { $_.Alias}) -contains $userAlias }

if ($null -ne $Office365GroupsMember){
Write-Host "Removing user from the following 365 Groups: $($Office365GroupsMember -join ", ")"
$Office365GroupsMember | ForEach-Object {
    Remove-UnifiedGroupLinks -Identity $_ -LinkType Member -Links $userDN -Confirm:$false
}
}
else {
    Write-Host "User not found in any Office 365 groups."
}
