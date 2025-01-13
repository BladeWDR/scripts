# Back up the key protectors from already-encrypted machines to AD.
#
(Get-BitlockerVolume -MountPoint "C").KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword'} | Foreach-Object { $protectorid = "$($_.KeyProtectorId)"}

if ((gwmi win32_computersystem).partofdomain -eq $true){
    Backup-BitLockerKeyProtector -Mountpoint "C" -KeyProtectorId $protectorid
}

