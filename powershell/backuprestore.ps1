# script to back up user directories

$folders = @("Documents", "Desktop", "Downloads", "Pictures", "Music")

Function Speak
{
    param (
        [string]$message
    )
    Add-Type -AssemblyName System.Speech
    $SpeechSynthesizer = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $SpeechSynthesizer.Speak($message)
}

function FolderPicker
{

    Add-Type -AssemblyName System.Windows.Forms
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select backup destination"
    $folderBrowser.rootfolder = "MyComputer"
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
    {
        $backupPath = $folderBrowser.SelectedPath
    }
    return $backupPath
}

$backupPath = FolderPicker

if([string]::IsNullorWhitespace($backupPath))
{
    Write-Output "Backup path cannot be empty."
    exit 1
}

Clear-Host

Write-Output "You are operating with the following directories:"
Write-Output "`n"
Write-Output "System folders:"
foreach ($folder in $folders)
{
    Write-Output "$env:USERPROFILE\$folder"
}

Write-Output "`n"
Write-Output 'Backup directory:'
$backupPath

Write-Output "`n"
Write-Host 'Enter 1 for a backup, or 2 for a restore.'
$choice = Read-Host 'Enter 1 or 2' 

# backup
if ($choice -eq "1")
{
    foreach ($folder in $folders)
    {
        if ((Test-Path -Path "$env:USERPROFILE\$folder"))
        {
            robocopy $env:USERPROFILE\$folder $backupPath\$folder /MT:16 /e /copy:dat /dcopy:dat
        } else
        {
            Write-Host -ForegroundColor Cyan "Path $env:USERPROFILE\$folder does not exist. Skipping."
        }
    }
    Speak "Backup Complete."
}
# restore
elseif ($choice -eq "2")
{
    foreach ($folder in $folders)
    {
        if ((Test-Path -Path "$backupPath\$folder"))
        {
            robocopy $backupPath\$folder $env:USERPROFILE\$folder /MT:16 /e /copy:dat /dcopy:dat
        } else
        {
            Write-Host -ForegroundColor Cyan "Path $backupPath\$folder does not exist. Skipping."
        }
    }
    Speak "Restore Complete."
} else
{
    Write-Output 'Invalid entry. Only enter 1 or 2.'
}
