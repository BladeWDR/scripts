param(
    [switch]$DryRun
)

$Robocopy_Flags = @("/MT:16", "/e", "/copy:dat", "/dcopy:dat")

if($DryRun)
{
    $Robocopy_Flags += "/L"
    Write-Host "DRY RUN MODE - No files will be copied" -ForegroundColor Yellow
}

$folders = @("Documents", "Desktop", "Downloads", "Pictures", "Music")
$LOG_DATESTAMP="$((Get-Date).ToString('yyyyMMddHHmmss'))"
$logPath = "$env:TEMP\$LOG_DATESTAMP.log"
Start-Transcript -Path "$logPath"

# Load assemblies once at the beginning
Add-Type -AssemblyName System.Speech
Add-Type -AssemblyName System.Windows.Forms

Function Speak
{
    param (
        [string]$message
    )
    if(-not $DryRun)
    {
        $SpeechSynthesizer = New-Object System.Speech.Synthesis.SpeechSynthesizer
        $SpeechSynthesizer.Speak($message)
    } else
    {
        Write-Host "[DRY RUN] Would speak: $message" -ForegroundColor Yellow
    }
}

function FolderPicker
{
    param(
        [string]$Destination
    )
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "$Destination"
    $folderBrowser.rootfolder = "MyComputer"
    
    $selectedPath = $null  # Initialize variable
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
    {
        $selectedPath = $folderBrowser.SelectedPath
    }
    return $selectedPath
}

$backupPath = FolderPicker -Destination "Select backup destination."
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

if($DryRun)
{
    Write-Host "DRY RUN MODE ENABLED - No actual operations will be performed" -ForegroundColor Yellow
    Write-Output "`n"
}

Write-Host 'Enter 1 for a backup, or 2 for a restore.'
$choice = Read-Host 'Enter 1 or 2' 

# backup
if ($choice -eq "1")
{
    foreach ($folder in $folders)
    {
        if ((Test-Path -Path "$env:USERPROFILE\$folder"))
        {
            Write-Host "Backing up $folder..." -ForegroundColor Green
            $result = robocopy "$env:USERPROFILE\$folder" "$backupPath\$folder" $Robocopy_Flags
            if ($LASTEXITCODE -ge 8)
            {
                Write-Warning "Robocopy encountered errors backing up $folder (Exit code: $LASTEXITCODE)"
            }
        } else
        {
            Write-Host -ForegroundColor Cyan "Path $env:USERPROFILE\$folder does not exist. Skipping."
        }
    }
    
    # Reset choice to empty string so I can reuse it.
    $choice = ""
    $choice = Read-Host "Would you like to export device drivers? (Y/N)"
    if(($choice -eq "y") -or ($choice -eq "Y"))
    {
        $driverPath = FolderPicker -Destination "Select driver export location"
        if([string]::IsNullorWhitespace($driverPath))
        {
            Write-Output "Driver export path cannot be empty."
            exit 1
        }
        
        if($DryRun)
        {
            Write-Host "[DRY RUN] Would export drivers to: $driverPath" -ForegroundColor Yellow
        } else
        {
            Write-Host "Exporting drivers..." -ForegroundColor Green
            try
            {
                $result = pnputil.exe /export-driver * "$driverPath"
                if ($LASTEXITCODE -ne 0)
                {
                    Write-Warning "Driver export may have encountered issues (Exit code: $LASTEXITCODE)"
                }
            } catch
            {
                Write-Error "Failed to export drivers: $_"
            }
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
            Write-Host "Restoring $folder..." -ForegroundColor Green
            $result = robocopy "$backupPath\$folder" "$env:USERPROFILE\$folder" $Robocopy_Flags
            if ($LASTEXITCODE -ge 8)
            {
                Write-Warning "Robocopy encountered errors restoring $folder (Exit code: $LASTEXITCODE)"
            }
        } else
        {
            Write-Host -ForegroundColor Cyan "Path $backupPath\$folder does not exist. Skipping."
        }
    }
    
    $choice = ""
    $choice = Read-Host "Would you like to import device drivers? (Y/N)"
    if(($choice -eq "y") -or ($choice -eq "Y"))
    {
        $driverPath = FolderPicker -Destination "Select driver import location"
        if([string]::IsNullorWhitespace($driverPath))
        {
            Write-Output "Driver import path cannot be empty."
            exit 1
        }
        
        if($DryRun)
        {
            Write-Host "[DRY RUN] Would import drivers from: $driverPath" -ForegroundColor Yellow
        } else
        {
            Write-Host "Importing drivers..." -ForegroundColor Green
            try
            {
                $result = pnputil.exe /add-driver "$driverPath\*.inf" /subdirs /install
                if ($LASTEXITCODE -ne 0)
                {
                    Write-Warning "Driver import may have encountered issues (Exit code: $LASTEXITCODE)"
                }
            } catch
            {
                Write-Error "Failed to import drivers: $_"
            }
        }
    }
    Speak "Restore Complete."
} else
{
    Write-Output 'Invalid entry. Only enter 1 or 2.'
}

Stop-Transcript
