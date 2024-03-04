# Get-DistributionListMembers.ps1
# personal modification of a script I found here: https://github.com/12Knocksinna/Office365itpros/blob/master/ReportDLsAndManagers.PS1

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

$OrgName = (Get-OrganizationConfig).Name
$CreationDate = Get-Date -format g
$ReportFile = "$env:userprofile\Downloads\DLManagersReport.html"
$pdfPath = "$env:userprofile\Downloads\DLManagersReport.pdf"

Write-Host "Finding Distribution lists in" $OrgName "..."
[array]$DLs = Get-DistributionGroup -ResultSize Unlimited -Filter {RecipientTypeDetails -ne "Roomlist"} | Select-Object DisplayName, ExternalDirectoryObjectId, ManagedBy, DistinguishedName, PrimarySmtpAddress
If (!($DLs)) { Write-Host "No distribution lists found - exiting" ; break }

$Report = [System.Collections.Generic.List[Object]]::new()
$GroupReport = [System.Collections.Generic.List[Object]]::new()

Write-Host "Reporting Distribution lists and managers..."
ForEach ($DL in $DLs) {
    $ManagerList = [System.Collections.Generic.List[Object]]::new()
    $MembersList = @()
    $MembersList = Get-DistributionGroupMember -Identity $DL.DistinguishedName | Select-Object -ExpandProperty DisplayName
    ForEach ($Manager in $DL.ManagedBy) {
       $Recipient = Get-Recipient -Identity $Manager -ErrorAction SilentlyContinue
       If (!($Recipient)) { # Can't resolve manager
           $Recipient = "Unknown user" }
       $ManagerLine = [PSCustomObject][Ordered]@{  
         DisplayName = $Recipient.DisplayName
         UPN         = $Recipient.WIndowsLiveID }
       $ManagerList.Add($ManagerLine) 
    } # End processing managers
    $Managers = $ManagerList.DisplayName -join ", " 
    $Members = $MembersList -join ", "
    $DLLine = [PSCustomObject][Ordered]@{    
         DisplayName  = $DL.DisplayName     
         Managers     = $Managers
         'Email Address' = $DL.PrimarySmtpAddress 
         Members = $Members }
    $Report.Add($DLLine)
} # End processing DL

[array]$o365groups = Get-UnifiedGroup -ResultSize Unlimited | Select-Object DisplayName, ExternalDirectoryObjectId, ManagedBy, DistinguishedName, PrimarySmtpAddress
Write-Host 'Reporting O365 Groups and Managers...'
ForEach ($o365group in $o365Groups) {
    $ManagerList = [System.Collections.Generic.List[Object]]::new()
    $MembersList = @()
    $MembersList = Get-UnifiedGroupLinks -Identity $o365group.DistinguishedName -LinkType Members | Select-Object -ExpandProperty DisplayName
    ForEach ($Manager in $o365group.ManagedBy) {
       $Recipient = Get-Recipient -Identity $Manager -ErrorAction SilentlyContinue
       If (!($Recipient)) { # Can't resolve manager
           $Recipient = "Unknown user" }
       $ManagerLine = [PSCustomObject][Ordered]@{  
         DisplayName = $Recipient.DisplayName
         UPN         = $Recipient.WIndowsLiveID }
       $ManagerList.Add($ManagerLine) 
    } # End processing managers
    $Managers = $ManagerList.DisplayName -join ", " 
    $Members = $MembersList -join ", "
    $o365groupLine = [PSCustomObject][Ordered]@{    
         DisplayName  = $o365group.DisplayName     
         Managers     = $Managers
         'Email Address' = $o365group.PrimarySmtpAddress 
         Members = $Members }
    $GroupReport.Add($o365groupLine)
} # End processing DL



# Create the HTML report
$htmlhead="<html>
	   <style>
	   BODY{font-family: Arial; font-size: 8pt;}
       width: 100%
	   H1{font-size: 22px; font-family: 'Segoe UI Light','Segoe UI','Lucida Grande',Verdana,Arial,Helvetica,sans-serif;}
	   H2{font-size: 18px; font-family: 'Segoe UI Light','Segoe UI','Lucida Grande',Verdana,Arial,Helvetica,sans-serif;}
	   H3{font-size: 16px; font-family: 'Segoe UI Light','Segoe UI','Lucida Grande',Verdana,Arial,Helvetica,sans-serif;}
	   TABLE{border: 1px solid black; border-collapse: collapse; font-size: 8pt; width: 100%}
	   TH{border: 1px solid #969595; background: #dddddd; padding: 5px; color: #000000;}
	   TD{border: 1px solid #969595; padding: 5px; }
	   td.pass{background: #B7EB83;}
	   td.warn{background: #FFF275;}
	   td.fail{background: #FF2626; color: #ffffff;}
	   td.info{background: #85D4FF;}
	   </style>
	   <body>
           <div align=center>
           <p><h1>Distribution List Report</h1></p>
           <p><h2><b>For the " + $Orgname + " organization</b></h2></p>
           <p><h3>Generated: " + (Get-Date -format g) + "</h3></p></div>
           <div align=center>"

$htmlbody1 = $Report | ConvertTo-Html -Fragment
$htmlbody2 = $GroupReport | ConvertTo-Html -Fragment

$htmltail = "</div><p>Report created for: " + $OrgName + "</p>" +
             "<p>Created: " + $CreationDate + "<p>" +
             "<p>-----------------------------------------------------------------------------------------------------------------------------</p>"+  
             "<p>Number of distribution lists found:    " + $DLs.Count + "</p>" +
             "<p>Number of office 365 groups found:     " + $o365groups.Count + "</p>"+
             "<p>-----------------------------------------------------------------------------------------------------------------------------</p>"

$htmlreport = $htmlhead + $htmlbody1 + "<br/>" + $htmlbody2 + $htmltail
$htmlreport | Out-File $ReportFile  -Encoding UTF8

# Generate PDF file using microsoft edge's print to pdf functionality.
Write-Host 'Generating PDF file...'
Start-Process "msedge.exe" -ArgumentList @("--headless","--print-to-pdf=""$pdfPath""","--disable-extensions","--print-to-pdf-no-header","--disable-popup-blocking","--run-all-compositor-stages-before-draw","--disable-checker-imaging", "file:///$ReportFile")
Write-Host "Removing source HTML document..."
Remove-Item -Path $ReportFile -Confirm $false
Clear-Host
Write-Host "PDF file created and saved to $pdfPath"

#Write-Host "All done. Output files is $ReportFile"
