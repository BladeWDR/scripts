# in: mailbox name. out: csv file with folders sorted by size.
# do i need to convert to bytes?
#

param(
    [Parameter(Mandatory)][string]$mailbox
)

if([string]::IsNullOrWhiteSpace($mailbox)){
    Write-Host "Sorry, you must specify a mailbox. i.e. john.smith@domain.tld"
    }

$inboxstats = Get-MailboxFolderStatistics $mailbox | Select-Object Name, FolderandSubFolderSize

foreach ($folder in $inboxstats){
    $folder.FolderandSubFolderSize = $folder.FolderandSubFolderSize.ToMB()
    #$folder.FolderandSubFolderSize = $a / 1MB
}

#Write-Host $inboxstats
