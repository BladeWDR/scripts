# script to back up user directories

$folders = @("Documents", "Desktop", "Downloads", "Pictures", "Music")

Write-Output "Enter the path for the backup directory (e.g. D:\mybackup or \\fileserver\backupshare)"
Write-Output "This should be on a separate drive, preferably a removable one or network drive."
$backupPath = Read-Host 'Enter path'
Clear-Host

Write-Output "You are operating with the following directories:"
Write-Output "`n"
Write-Output "System folders:"
foreach ($folder in $folders){
    Write-Output "$env:USERPROFILE\$folder"
}

Write-Output "`n"
Write-Output 'Backup directory:'
$backupPath

Write-Output "`n"
Write-Host 'Enter 1 for a backup, or 2 for a restore.'
$choice = Read-Host 'Enter 1 or 2' 

# backup
if ($choice -eq "1"){
    foreach ($folder in $folders){
        robocopy $env:USERPROFILE\$folder $backupPath\$folder /MT:16 /e /copy:dat /dcopy:dat
    }
}
# restore
elseif ($choice -eq "2"){
    foreach ($folder in $folders){
        robocopy $backupPath\$folder $env:USERPROFILE\$folder /MT:16 /e /copy:dat /dcopy:dat
    }
}
else{
    Write-Output 'Invalid entry. Only enter 1 or 2.'
}
