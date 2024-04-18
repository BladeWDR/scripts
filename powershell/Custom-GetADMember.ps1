$groupname = "Employee-Share-Publisher"
$filePath = ""
$realmembers = @()

function custom-getmembers {
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
$memberList | Export-Csv -path $filePath -NoTypeInformation

