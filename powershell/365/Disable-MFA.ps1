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
    Connect-MsolService -credential $(Get-Credential -UserName $adminuser -Message "Enter password for $adminuser")
}

$username = Read-Host -Prompt "Please specify the users full name. i.e. John Smith:"
$user = Get-MsolUser -All | Where-Object {$_.DisplayName -eq $username}

if($user){

    $displayname = $user.DisplayName
    $email = $user.UserPrincipalName

    $choice = Read-Host "You're clearing the MFA methods for $displayname `(email address $email`). Is this correct? y/n"

    if($choice -eq "y"){
        #Set-MsolUser -UserPrincipalName $user -StrongAuthenticationRequirements @()
        Write-Output "MFA methods for $displayname have been cleared."
    }
    elseif($choice -eq "n"){
        Write-Output "MFA methods for $displayname have not been altered."
    }
    else{
        Write-Output "Invalid input, please enter y or n."
    }
}
else{
    Write-Host "User not found."
}

#Disconnect the session when done.
[Microsoft.Online.Administration.Automation.ConnectMsolService]::ClearUserSessionState() | Out-Null
