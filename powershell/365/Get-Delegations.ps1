###################################################
# Get-Delegations.ps1 myadminuser@domain.onmicrosoft.com
# Gets all 365 mailboxes who have delegated access to their mailbox.
# Includes both User and Shared mailbox types.
###################################################

param(
    [Parameter()][string]$defaultValue
)
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
    Connect-ExchangeOnline -UserPrincipalName $defaultValue | Out-Null
}
# Get list of all mailboxes, shared and actual
$mailboxPermissions = @()
$delegates = @()

$OrgName = (Get-OrganizationConfig).Name
$CreationDate = Get-Date -format g
$ReportFile = "$env:userprofile\Downloads\DelegatesReport.html"
$pdfPath = "$env:userprofile\Downloads\DelegatesReport.pdf"

# Get all mailboxes
$mailboxes = Get-Mailbox -ResultSize Unlimited

# Iterate over mailboxes and check for delegations
Write-Host "Checking delegation status. This may take a few minutes, go grab a coffee."
foreach ($mailbox in $mailboxes) {
    # Get mailbox delegates
    #write-host "Checking $mailbox"
    $delegates = Get-MailboxPermission -Identity $mailbox.DistinguishedName  | Where-Object { $_.IsInherited -eq $false -and $_.User -ne "NT AUTHORITY\SELF" }
# If delegates exist, add them to the array
if ($delegates) {
    foreach ($delegate in $delegates) {
        $sendAs = Get-RecipientPermission -Identity $mailbox.DistinguishedName -Trustee $delegate.User | Where-Object { $_.Trustee -ne "NT_AUTHORITY\SELF"}
        if ($null -ne $sendAs) {
            $sendAsExists = "true"
        }
        else {
            $sendAsExists = "false"
        }
        $mailboxPermissions += [PSCustomObject]@{
            "Mailbox" = $mailbox.UserPrincipalName
                "Delegate" = $delegate.User
                "Access Rights" = $delegate.AccessRights
                "Sending Rights" = $sendAsExists
        }
    }
}
}
# Create the HTML report
$htmlhead="<html>
	   <style>
	   BODY{font-family: Arial; font-size: 8pt;}
       width: 100%
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
           <p><h1>Email Delegation Report</h1></p>
           <p><h2><b>For the " + $Orgname + " organization</b></h2></p>
           <p><h3>Generated: " + (Get-Date -format g) + "</h3></p></div>
           <div align=center>"

$htmlbody1 = $mailboxPermissions | ConvertTo-Html -Fragment

$htmltail = "</div><p>Report created for: " + $OrgName + "</p>" +
             "<p>Created: " + $CreationDate + "<p>"

# create the report
$htmlreport = $htmlhead + $htmlbody1 + $htmltail
$htmlreport | Out-File $ReportFile  -Encoding UTF8

# Convert to PDF and delete the HTML version.
Write-Host 'Generating PDF file...'
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList @("--headless","--print-to-pdf=""$pdfPath""","--disable-extensions","--print-to-pdf-no-header","--disable-popup-blocking","--run-all-compositor-stages-before-draw","--disable-checker-imaging", "file:///$ReportFile") | Out-Null 
Write-Host "Removing source HTML document..."
Remove-Item -Path $ReportFile -Confirm:$false -Force

Clear-Host
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXX"
Write-Host "Exported to $pdfPath"
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXX"
