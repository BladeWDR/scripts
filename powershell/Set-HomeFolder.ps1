<#
    .SYNOPSIS Set up user home directories in an existing Active Directory forest.
    .EXAMPLE .\Set-HomeFolder.ps1 -HOMEFOLDERPATH '\\fileserver\UsersFolders$' -HOMEDRIVE 'U:' -SEARCHBASE 'OU=ContosoUsers,DC=Contoso,DC=com'
#>

Import-Module ActiveDirectory

param (
    [Parameter(Mandatory=$true)][string]$HOMEFOLDERPATH,
    [string]$HOMEDRIVE='U:',
    [Parameter(Mandatory=$true)][string]$SEARCHBASE
)

$LOG_DATESTAMP="$((Get-Date).ToString('yyyyMMddHHmmss'))"
$TEMPDIR='C:\Temp'
$LOGFILE="$TEMPDIR\Set-HomeFolder-$LOG_DATESTAMP.log"

if (-not (Test-Path -Path $TEMPDIR))
{
    New-Item -Path $TEMPDIR -ItemType directory
}

Start-Transcript -Path "$LOGFILE" -NoClobber

$USERS = Get-ADUser -SearchBase "$SEARCHBASE" -Filter 'enabled -eq $true' -properties SamAccountName | Select-Object -Property SamAccountName

foreach ($user in $USERS)
{
    $USERNAME=$($user.SamAccountName)
    $USERHOMEDIR="$HOMEFOLDERPATH\$USERNAME"

    if (-not (Test-Path -Path $USERHOMEDIR))
    {
        Write-Host "Creating user home directory $USERHOMEDIR"
        New-Item -Path "$USERHOMEDIR" -ItemType directory
	
        # Give that user full control over the directory.
        $acl = Get-Acl -Path "$USERHOMEDIR"
        $FULLCONTROL = New-Object System.Security.AccessControl.FileSystemAccessRule("$env:USERDOMAIN\$USERNAME", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.SetAccessRule($FULLCONTROL)
        Set-Acl -Path "$USERHOMEDIR" $acl
    }

    Write-Output "Setting $USERNAME home directory as $USERHOMEDIR"

    try
    {
        Set-ADUser -Identity $USERNAME -HomeDirectory "$USERHOMEDIR" -HomeDrive "$HOMEDRIVE"
    } catch
    {
        Write-Error "Unable to set home directory for $USERNAME"
        Write-Error "Error Message: $($_.Exception.Message)"
        Write-Error "Error Stack Trace: $($_.Exception.StackTrace)"
    }
}

Stop-Transcript
