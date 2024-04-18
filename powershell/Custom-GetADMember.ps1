param(
    [Parameter(Mandatory)[string]$groupname]
)
if([string]::IsNullOrWhiteSpace($groupname){
    Read-Host "you must enter a group name!"; EXIT
    }


function custom-getmembers {
    $realmembers = @()

    param (
        [string]$group
    )

    $groupmembers = Get-ADGroupMember -Identity $group

    foreach($member in $groupmembers) {
        if($member.objectClass -eq "group"){
            custom-getmembers -group $member
        }
        else{
            $realmembers += $member.name
        }
    }
    return $realmembers
}

$members = custom-getmembers -group $groupname | Sort-Object -Unique

$memberList = $members | Select-Object @{Name='Name';Expression={$_}}
$memberList | Export-Csv -path "$env:USERPROFILE\Downloads\$groupname.csv" -NoTypeInformation

