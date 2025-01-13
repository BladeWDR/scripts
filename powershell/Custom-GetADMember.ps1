# Uses recursive function get all effective members of a group. (including nested groups)
# Custom-GetADMember.ps1 -groupname whatevergroup
param(
    [Parameter(Mandatory)][string]$groupname
)
if([string]::IsNullOrWhiteSpace($groupname)){
    Read-Host "you must enter a group name!"; EXIT
    }

function custom-getmembers {
    param (
            [string]$group
          )

    $realmembers = @()

    $groupmembers = Get-ADGroupMember -Identity $group

    foreach($member in $groupmembers) {
        if($member.objectClass -eq "group"){
            custom-getmembers -group $member
        }
        else{
            $realmembers += $member
        }
    }
    return $realmembers
}

$members = custom-getmembers -group $groupname | Sort-Object -Unique

$members | Select-Object name | Export-Csv -path "$env:USERPROFILE\Downloads\$groupname.csv" -NoTypeInformation 
