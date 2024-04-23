# Remove all existing MFA methods for a user in Office 365.

param(
    [Parameter(Mandatory)][string]$adminuser
)

if([string]::IsNullOrWhiteSpace($adminuser)){
    Write-Output "You must enter an admin user!"; EXIT
}

try{
    Import-Module -Name MSOnline | Out-Null
    Clear-Host
    Write-Output 'Module imported successfully.'
}
catch{
    Write-Output "MSOnline module missing, installing..."
    Install-Module -Name MSOnline -allowClobber
    Import-Module -Name MSOnline | Out-Null
    clear-host
}
finally{
    Connect-MsolService -credential (Get-Credential -UserName $adminuser -Message "Enter password for $adminuser")
}

$user = Read-Host -Prompt "Please specify the email address of the user:"
$displayname = (Get-MsolUser -UserPrincipalName $user).DisplayName

Set-MsolUser -UserPrincipalName $user -StrongAuthenticationRequirements @()
Write-Output "MFA methods for $displayname have been cleared."
