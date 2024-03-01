# Get-DistributionListMembers.ps1
# https://github.com/12Knocksinna/Office365itpros/blob/master/ReportDLsAndManagers.PS1

try {
    Import-Module ExchangeOnlineManagement
}
catch {
    Write-Host "ExchangeOnlineManagement module not installed, installing..."
    Install-Module ExchangeOnlineManagement -AllowClobber | Out-Null
    Write-Host "Installed succesfully."
    Import-Module ExchangeOnlineManagement
}
finally {
    Connect-ExchangeOnline
}

$OrgName="EltraSelf"
$CreationDate = Get-Date -format g
$members=@()
$dlMembers=@()
$outputFile="$env:userprofile\Downloads\distributionlistmembers.html"
$groups = Get-DistributionGroup -ResultSize Unlimited -SortBy Name 
$Report = [System.Collections.Generic.List[Object]]::new()

foreach ($group in $groups){
    $members += Get-DistributionGroupMember -Identity $group.DistinguishedName | Select-Object -ExpandProperty DisplayName
        $dlMembers += [PSCustomObject]@{
            "Distribution List" = $group.DisplayName
            "Members" = $members -join " ; "
    }
}
#Clear-Host
#export to csv
#$dlMembers | Export-Csv -Path $outputFile -NoTypeInformation

# Create the HTML report
$htmlhead="<html>
	   <style>
	   BODY{font-family: Arial; font-size: 8pt;}
	   H1{font-size: 22px; font-family: 'Segoe UI Light','Segoe UI','Lucida Grande',Verdana,Arial,Helvetica,sans-serif;}
	   H2{font-size: 18px; font-family: 'Segoe UI Light','Segoe UI','Lucida Grande',Verdana,Arial,Helvetica,sans-serif;}
	   H3{font-size: 16px; font-family: 'Segoe UI Light','Segoe UI','Lucida Grande',Verdana,Arial,Helvetica,sans-serif;}
	   TABLE{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
	   TH{border: 1px solid #969595; background: #dddddd; padding: 5px; color: #000000;}
	   TD{border: 1px solid #969595; padding: 5px; }
	   td.pass{background: #B7EB83;}
	   td.warn{background: #FFF275;}
	   td.fail{background: #FF2626; color: #ffffff;}
	   td.info{background: #85D4FF;}
	   </style>
	   <body>
           <div align=center>
           <p><h1>Distribution List Manager Report</h1></p>
           <p><h2><b>For the " + $Orgname + " organization</b></h2></p>
           <p><h3>Generated: " + (Get-Date -format g) + "</h3></p></div>"



Write-Host "XXXXXXXXXXXXXXXXXXXXXXXX"
Write-Host "Exported to $outputFile"
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXX"
