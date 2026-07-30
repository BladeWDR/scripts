<#
.SYNOPSIS
    Automated Backup & Restore Utility with Driver Management.
.DESCRIPTION
    Backs up or restores standard user profile folders using Robocopy 
    and handles Windows driver export/import via PNPUtil.
.PARAMETER DryRun
    Simulate operations without making changes.
.PARAMETER Mode
    Specify operation mode ('Backup' or 'Restore'). Skips initial menu if provided.
.PARAMETER BackupPath
    Specify target backup directory. Skips folder browser if provided.
.PARAMETER NoSpeech
    Disable Text-to-Speech audio notifications.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateSet("Backup", "Restore")]
    [string]$Mode,
    [string]$BackupPath,
    [switch]$NoSpeech
)

# -----------------------------------------------------------------------------
# Global Config & Flags
# -----------------------------------------------------------------------------
$RobocopyFlags = @("/MT:16", "/E", "/COPY:DAT", "/DCOPY:DAT", "/R:2", "/W:2")
if ($DryRun) {
    $RobocopyFlags += "/L"
}

$SystemFolders = @("Documents", "Desktop", "Downloads", "Pictures", "Music")
$LogTimestamp  = (Get-Date).ToString("yyyyMMdd_HHmmss")
$LogPath       = Join-Path $env:TEMP "$LogTimestamp.log"

# -----------------------------------------------------------------------------
# Visual & Helper Functions
# -----------------------------------------------------------------------------
function Write-HeaderBanner {
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "                USER DATA BACKUP & RESTORE UTILITY                   " -ForegroundColor Yellow
    Write-Host "======================================================================" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host " [?] DRY-RUN MODE ACTIVE - No changes will be made to disk" -ForegroundColor DarkYellow
        Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
    }
    Write-Host ""
}

function Write-Badge {
    param(
        [string]$Type,
        [string]$Message
    )
    switch ($Type) {
        "INFO"    { Write-Host "[*] " -ForegroundColor Cyan -NoNewline; Write-Host $Message }
        "SUCCESS" { Write-Host "[+] " -ForegroundColor Green -NoNewline; Write-Host $Message }
        "WARN"    { Write-Host "[!] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        "ERROR"   { Write-Host "[x] " -ForegroundColor Red -NoNewline; Write-Host $Message }
        "DRYRUN"  { Write-Host "[?] " -ForegroundColor DarkYellow -NoNewline; Write-Host $Message }
    }
}

function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Speak-Notification {
    param ([string]$Message)
    if ($NoSpeech) { return }
    
    if (-not $DryRun) {
        try {
            Add-Type -AssemblyName System.Speech -ErrorAction Stop
            $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
            $synth.Speak($Message)
        } catch {
            # Ignore speech synthesizer errors gracefully
        }
    } else {
        Write-Badge "DRYRUN" "Speech Triggered: '$Message'"
    }
}

function Get-FolderInteractive {
    param ([string]$Description)
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Description
    $dialog.ShowNewFolderButton = $true
    
    # Force dialog to top layer
    $topForm = New-Object System.Windows.Forms.Form
    $topForm.TopMost = $true
    
    if ($dialog.ShowDialog($topForm) -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    }
    return $null
}

# -----------------------------------------------------------------------------
# Main Script Execution
# -----------------------------------------------------------------------------
Start-Transcript -Path $LogPath -Quiet

try {
    Write-HeaderBanner

    # Check for Admin Privileges (required for PNPUtil)
    $IsAdmin = Test-IsAdmin
    if (-not $IsAdmin) {
        Write-Badge "WARN" "Script is NOT running as Administrator. Driver import/export will fail if selected."
        Write-Host ""
    }

    # Prompt for Target Path if not supplied via parameter
    while ([string]::IsNullOrWhiteSpace($BackupPath)) {
        Write-Badge "INFO" "Select the root directory for Backup/Restore operations..."
        $BackupPath = Get-FolderInteractive -Description "Select Backup/Restore Root Directory"
        
        if ([string]::IsNullOrWhiteSpace($BackupPath)) {
            Write-Badge "WARN" "No directory selected."
            $choice = Read-Host "Would you like to try again? (Y/N)"
            if ($choice -notmatch "^[Yy]") {
                Write-Badge "ERROR" "Operation cancelled by user."
                exit 0
            }
        }
    }

    # Confirmation Summary Card
    Write-HeaderBanner
    Write-Host " [CONFIG SUMMARY]" -ForegroundColor Yellow
    Write-Host "  Profile Source : $env:USERPROFILE"
    Write-Host "  Target Location: $BackupPath"
    Write-Host "  Log Output     : $LogPath"
    Write-Host "  Folders        : $($SystemFolders -join ', ')"
    Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""

    # Menu Selection if Mode parameter was omitted
    if ([string]::IsNullOrWhiteSpace($Mode)) {
        Write-Host " Select Operation:" -ForegroundColor Yellow
        Write-Host "   [1] Backup User Data (Profile -> Backup Directory)"
        Write-Host "   [2] Restore User Data (Backup Directory -> Profile)"
        Write-Host "   [Q] Quit"
        Write-Host ""
        
        $selection = Read-Host " Enter choice (1/2/Q)"
        switch ($selection) {
            "1" { $Mode = "Backup" }
            "2" { $Mode = "Restore" }
            default {
                Write-Badge "INFO" "Exiting without making changes."
                exit 0
            }
        }
    }

    Write-Host ""
    Write-Badge "INFO" "Starting $Mode process..."

    # Backup Mode
    if ($Mode -eq "Backup") {
        foreach ($folder in $SystemFolders) {
            $src = Join-Path $env:USERPROFILE $folder
            $dst = Join-Path $BackupPath $folder

            if (Test-Path -Path $src) {
                Write-Badge "INFO" "Backing up $folder..."
                $null = robocopy "$src" "$dst" $RobocopyFlags
                
                if ($LASTEXITCODE -ge 8) {
                    Write-Badge "ERROR" "Robocopy failed for $folder (Exit Code: $LASTEXITCODE)"
                } else {
                    Write-Badge "SUCCESS" "Backed up $folder successfully."
                }
            } else {
                Write-Badge "WARN" "Source directory '$src' does not exist. Skipping."
            }
        }

        # Driver Export Option
        $driverChoice = Read-Host "`nWould you like to export device drivers? (Y/N)"
        if ($driverChoice -match "^[Yy]") {
            if (-not $IsAdmin) {
                Write-Badge "ERROR" "Exporting drivers requires Administrator privileges."
            } else {
                $driverPath = Get-FolderInteractive -Description "Select driver export location"
                if ([string]::IsNullOrWhiteSpace($driverPath)) {
                    $driverPath = Join-Path $BackupPath "Drivers"
                }
                if (-not (Test-Path $driverPath)) { New-Item -ItemType Directory -Path $driverPath | Out-Null }

                Write-Badge "INFO" "Exporting drivers to $driverPath..."
                if ($DryRun) {
                    Write-Badge "DRYRUN" "Would run: pnputil.exe /export-driver * '$driverPath'"
                } else {
                    $result = pnputil.exe /export-driver * "$driverPath"
                    if ($LASTEXITCODE -eq 0) {
                        Write-Badge "SUCCESS" "Driver export complete."
                    } else {
                        Write-Badge "WARN" "Driver export completed with warnings/errors (Exit Code: $LASTEXITCODE)."
                    }
                }
            }
        }

        Speak-Notification "Backup Complete."
        Write-Badge "SUCCESS" "Backup procedure finished."
    }
    # Restore Mode
    elseif ($Mode -eq "Restore") {
        foreach ($folder in $SystemFolders) {
            $src = Join-Path $BackupPath $folder
            $dst = Join-Path $env:USERPROFILE $folder

            if (Test-Path -Path $src) {
                Write-Badge "INFO" "Restoring $folder..."
                $null = robocopy "$src" "$dst" $RobocopyFlags
                
                if ($LASTEXITCODE -ge 8) {
                    Write-Badge "ERROR" "Robocopy failed restoring $folder (Exit Code: $LASTEXITCODE)"
                } else {
                    Write-Badge "SUCCESS" "Restored $folder successfully."
                }
            } else {
                Write-Badge "WARN" "Backup directory '$src' not found. Skipping."
            }
        }

        # Driver Import Option
        $driverChoice = Read-Host "`nWould you like to import device drivers? (Y/N)"
        if ($driverChoice -match "^[Yy]") {
            if (-not $IsAdmin) {
                Write-Badge "ERROR" "Importing drivers requires Administrator privileges."
            } else {
                $driverPath = Get-FolderInteractive -Description "Select driver import location"
                if ([string]::IsNullOrWhiteSpace($driverPath)) {
                    $driverPath = Join-Path $BackupPath "Drivers"
                }
                if (Test-Path $driverPath) {
                    Write-Badge "INFO" "Importing drivers from $driverPath..."
                    if ($DryRun) {
                        Write-Badge "DRYRUN" "Would run: pnputil.exe /add-driver '$driverPath\*.inf' /subdirs /install"
                    } else {
                        $result = pnputil.exe /add-driver "$driverPath\*.inf" /subdirs /install
                        if ($LASTEXITCODE -eq 0) {
                            Write-Badge "SUCCESS" "Driver import complete."
                        } else {
                            Write-Badge "WARN" "Driver import completed with warnings/errors (Exit Code: $LASTEXITCODE)."
                        }
                    }
                } else {
                    Write-Badge "WARN" "Driver backup folder '$driverPath' not found."
                }
            }
        }

        Speak-Notification "Restore Complete."
        Write-Badge "SUCCESS" "Restore procedure finished."
    }

} finally {
    Stop-Transcript -Quiet
}
