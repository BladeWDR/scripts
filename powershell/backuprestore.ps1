# script to back up user directories

$folders = @("Documents", "Desktop", "Downloads", "Pictures", "Music")

$backupPath = Read-Host 'Enter the path for the backup directory'

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
Write-Host 'Do you want to do a backup (1) or a restore? (2)'
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
