<#
  .SYNOPSIS
  Removes user from all groups.

  .DESCRIPTION
  This script is intended to be used for offboarding.
  It will remove a user from any groups or distribution lists that they are a part of.

  .PARAMETER User
  The user to be removed.

  .EXAMPLE
  PS> .\Remove-FromGroups.ps1 -User bob@example.com
#>

param(
    [Parameter(Mandatory=$true,
    HelpMessage='Enter a user to be removed from all groups in an email address format.',
    ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$User
)

try {
    Import-Module ExchangeOnlineManagement
}
catch {
    Write-Host "EOM module not installed, installing..."
    Install-Module ExchangeOnlineManagement -AllowClobber | Out-Null
    Write-Host "Installed successfully."
}

Write-Output "Removing user $User from all distribution lists and 365 groups."
Write-Output "Stand by..."

$distributionLists = Get-DistributionGroup | Select-Object DistinguishedName,DisplayName
$office365Groups = Get-UnifiedGroup | Select-Object Name,DisplayName

[boolean]$userFound = $false

foreach ($list in $distributionLists) {

    $listDN = $list.DistinguishedName
    $listDisplayName = $list.DisplayName

    $distlistmembers = Get-DistributionGroupMember -Identity $listDN | Select-Object -ExpandProperty PrimarySmtpAddress
    
        if( $User -in $distlistmembers) {
            Remove-DistributionGroupMember -Identity $listDN -Member $User -Confirm:$false
            Write-Output "The user $User has been removed from the distribution list `"$listDisplayName`""
            $userFound = $true
        }
        else{
            Write-Verbose "User not found in distribution list `"$listDisplayName`"."
        }
}

if (-not ($userFound)){
    Write-Output "User not found in any distribution lists."
}

[boolean]$userFound = $false

foreach ($group in $office365Groups) {

        $groupName = $group.Name
        $groupDisplayName = $group.DisplayName
        $o365groupmembers = Get-UnifiedGroupLinks -Identity $groupName -LinkType Members | Select-Object -ExpandProperty PrimarySmtpAddress

        if( $User -in $o365groupmembers) {
            $userFound = $true
            $groupOwners = Get-UnifiedGroupLinks -Identity "$groupName" -LinkType Owners | Select-Object -ExpandProperty PrimarySmtpAddress
            $groupName
                if ( $User -in $groupOwners){
                    try {
                        Write-Output "Attempting to remove group ownership for `"$groupDisplayName`"..."
                        Remove-UnifiedGroupLinks -Identity $groupName -LinkType Owners -Links $User -Confirm:$false
                        Write-Output "Removed ownership from `"$groupDisplayName`" successfully."
                    }
                    catch {
                        Write-Host "Error removing user as an owner of $groupName. It's likely that they're the only owner of the group."
                    }
                }
            Remove-UnifiedGroupLinks -Identity $groupName -LinkType Members -Links $User -Confirm:$false
                Write-Output "The user $($User) has been removed from the Office 365 group `"$groupDisplayName`""
        }
        else{
            Write-Verbose "User not found in Office 365 group `"$groupDisplayName`"."
        }
}

if (-not ($userFound)){
    Write-Output "User not found in any Office 365 groups."
}
