<#
.DESCRIPTION to install Office 365 products using the Office Deployment Toolkit.
.PARAMETER ProductIDs - a comma separated list of Product IDs to install.
.PARAMETER UpdateChannel - Optional Parameter to specify the update channel. Defaults to Current.
.PARAMETER Language - Defaults to MatchOS.
.PARAMETER CompanyName - Defaults to "Office".

If no ProductIDs are provided, a GUI selection window will be shown.
#>

<# TO DO:

- Remove the web only options that Claude added for some reason.
- Add a text box to enter CompanyName via the GUI.
#>

param(
  [string[]]$ProductIDs,
  [string]$UpdateChannel = "Current",
  [string]$Language = 'MatchOS',
  [string]$CompanyName = 'Office'
)

# Force TLS1.2
[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)

# region vars
$TempDir = "$env:TEMP\InstallOffice"
$ODTLinkHtmlPath = "$TempDir\ODTLink.html"
$OD_Setup_exe = "$TempDir\setup.exe"
$OD_exe = "$TempDir\ODTool.exe"
$OD_XML_PATH = "$TempDir\365config.xml"

# Product catalog — DisplayName maps to ODT Product ID
$ProductCatalog = [ordered]@{
  # Office 365 Business
  "Microsoft 365 Apps for Business"                    = "O365BusinessRetail"
  "Microsoft 365 Business Standard"                    = "O365SmallBusPremRetail"
  "Microsoft 365 Business Basic (web/mobile only)"     = "O365BusinessEssentials"
  # Office 365 Enterprise
  "Microsoft 365 Apps for Enterprise (ProPlus)"        = "O365ProPlusRetail"
  "Office 365 Enterprise E1 (web/mobile only)"         = "O365EssentialsRetail"
  "Office 365 Enterprise E3"                           = "EnterprisePremiumRetail"
  # Project
  "Project Online Desktop Client (Project Pro)"        = "ProjectProRetail"
  "Project Online Essential (web only)"                = "ProjectEssentials"
  "Project Standard 2024"                              = "ProjectStd2024Volume"
  # Visio
  "Visio Plan 2 Desktop Client"                        = "VisioPro2024Volume"
  "Visio Plan 1 (web only)"                            = "VisioProRetail"
  "Visio Standard 2024"                                = "VisioStd2024Volume"
}

# region functions
function Show-ProductSelector {
  <#
  .SYNOPSIS
    Opens a WinForms GUI for selecting Office 365 products to install.
  .OUTPUTS
    String array of selected ODT Product IDs, or $null if cancelled.
  #>
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  # -- Form --
  $Form = New-Object System.Windows.Forms.Form
  $Form.Text = "Office 365 Product Installer"
  $Form.Size = New-Object System.Drawing.Size(520, 620)
  $Form.StartPosition = "CenterScreen"
  $Form.FormBorderStyle = "FixedDialog"
  $Form.MaximizeBox = $false
  $Form.MinimizeBox = $false
  $Form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
  $Form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

  # -- Header panel --
  $HeaderPanel = New-Object System.Windows.Forms.Panel
  $HeaderPanel.Size = New-Object System.Drawing.Size(520, 60)
  $HeaderPanel.Location = New-Object System.Drawing.Point(0, 0)
  $HeaderPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 114, 198)  # Microsoft blue
  $Form.Controls.Add($HeaderPanel)

  $HeaderLabel = New-Object System.Windows.Forms.Label
  $HeaderLabel.Text = "Select Office Products to Install"
  $HeaderLabel.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Regular)
  $HeaderLabel.ForeColor = [System.Drawing.Color]::White
  $HeaderLabel.AutoSize = $true
  $HeaderLabel.Location = New-Object System.Drawing.Point(16, 18)
  $HeaderPanel.Controls.Add($HeaderLabel)

  # -- Section helper: adds a bold group label --
  function Add-SectionLabel($text, $y) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $text
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(0, 114, 198)
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(16, $y)
    $Form.Controls.Add($lbl)
  }

  # -- Build checkboxes from catalog --
  $Checkboxes = @{}
  $yPos = 75

  $Sections = [ordered]@{
    "Microsoft 365 for Business" = @(
      "Microsoft 365 Apps for Business"
      "Microsoft 365 Business Standard"
      "Microsoft 365 Business Basic (web/mobile only)"
    )
    "Office 365 Enterprise" = @(
      "Microsoft 365 Apps for Enterprise (ProPlus)"
      "Office 365 Enterprise E1 (web/mobile only)"
      "Office 365 Enterprise E3"
    )
    "Project" = @(
      "Project Online Desktop Client (Project Pro)"
      "Project Online Essential (web only)"
      "Project Standard 2024"
    )
    "Visio" = @(
      "Visio Plan 2 Desktop Client"
      "Visio Plan 1 (web only)"
      "Visio Standard 2024"
    )
  }

  foreach ($section in $Sections.Keys) {
    Add-SectionLabel $section $yPos
    $yPos += 22

    foreach ($productName in $Sections[$section]) {
      $cb = New-Object System.Windows.Forms.CheckBox
      $cb.Text = $productName
      $cb.AutoSize = $true
      $cb.Location = New-Object System.Drawing.Point(24, $yPos)
      $cb.Tag = $ProductCatalog[$productName]  # Store the ODT ID in Tag
      $Form.Controls.Add($cb)
      $Checkboxes[$productName] = $cb
      $yPos += 22
    }
    $yPos += 8  # Extra spacing between sections
  }

  # -- Separator --
  $Separator = New-Object System.Windows.Forms.Panel
  $Separator.Size = New-Object System.Drawing.Size(480, 1)
  $Separator.Location = New-Object System.Drawing.Point(16, ($Form.ClientSize.Height - 56))
  $Separator.BackColor = [System.Drawing.Color]::Silver
  $Form.Controls.Add($Separator)

  # -- Buttons --
  $BtnInstall = New-Object System.Windows.Forms.Button
  $BtnInstall.Text = "Install"
  $BtnInstall.Size = New-Object System.Drawing.Size(90, 30)
  $BtnInstall.Location = New-Object System.Drawing.Point(306, ($Form.ClientSize.Height - 46))
  $BtnInstall.BackColor = [System.Drawing.Color]::FromArgb(0, 114, 198)
  $BtnInstall.ForeColor = [System.Drawing.Color]::White
  $BtnInstall.FlatStyle = "Flat"
  $BtnInstall.FlatAppearance.BorderSize = 0
  $BtnInstall.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $Form.Controls.Add($BtnInstall)
  $Form.AcceptButton = $BtnInstall

  $BtnCancel = New-Object System.Windows.Forms.Button
  $BtnCancel.Text = "Cancel"
  $BtnCancel.Size = New-Object System.Drawing.Size(90, 30)
  $BtnCancel.Location = New-Object System.Drawing.Point(406, ($Form.ClientSize.Height - 46))
  $BtnCancel.FlatStyle = "Flat"
  $BtnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $Form.Controls.Add($BtnCancel)
  $Form.CancelButton = $BtnCancel

  # -- Validate at least one product selected before allowing OK --
  $BtnInstall.Add_Click({
    $anyChecked = $Checkboxes.Values | Where-Object { $_.Checked }
    if (-not $anyChecked) {
      [System.Windows.Forms.MessageBox]::Show(
        "Please select at least one product to install.",
        "No Products Selected",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
      )
      $Form.DialogResult = [System.Windows.Forms.DialogResult]::None
    }
  })

  $Result = $Form.ShowDialog()

  if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
    return ($Checkboxes.Values | Where-Object { $_.Checked } | ForEach-Object { $_.Tag })
  } else {
    return $null
  }
}

function downloadFile {
  #downloadFile, build 32/seagull :: copyright datto, inc. :: MODIFIED VERSION; tls 1.2 happens on line 20
  param (
    [parameter(mandatory=$false)]$url,
    [parameter(mandatory=$false)]$whitelist,
    [parameter(mandatory=$false)]$filename,
    [parameter(mandatory=$false,ValueFromPipeline=$true)]$pipe
  )

  function setUserAgent {
    $script:WebClient = New-Object System.Net.WebClient
    $script:webClient.UseDefaultCredentials = $true
    $script:webClient.Headers.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f")
    $script:webClient.Headers.Add([System.Net.HttpRequestHeader]::UserAgent, 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705;)')
  }

  if (!$url)   { $url = $pipe }
  if (!$whitelist) { $whitelist = "the required web addresses." }
  if (!$filename)  { $filename = $url.split('/')[-1] }

  Write-Host "- Downloading: $url"
  setUserAgent
  $script:webClient.DownloadFile("$url", "$filename")

  if (!(Test-Path $filename)) {
    Write-Host "- ERROR: File $filename could not be downloaded."
    Write-Host "  Please ensure you are whitelisting $whitelist."
    Write-Host "- Operations cannot continue; exiting."
    exit 1
  } else {
    Write-Host "- Downloaded:  $filename"
  }
}

function verifyPackage ($file, $certificate, $thumbprint, $name, $url) {
  #verifyPackage build 4/seagull :: datto/kaseya
  if (!(Test-Path "$file")) {
    Write-Host "! ERROR: Downloaded file could not be found."
    Write-Host "  Please ensure firewall access to $url."
    exit 1
  }

  $varChain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
  try {
    $varChain.Build((Get-AuthenticodeSignature -FilePath "$file").SignerCertificate) | Out-Null
  } catch [System.Management.Automation.MethodInvocationException] {
    Write-Host "! ERROR: $name installer did not contain a valid digital certificate."
    Write-Host "  This could suggest a change in the way $name is packaged; it could"
    Write-Host "  also suggest tampering in the connection chain."
    Write-Host "- Please ensure $url is whitelisted and try again."
    Write-Host "  If this issue persists across different devices, please file a support ticket."
    exit 1
  }

  if ((Get-AuthenticodeSignature "$file").status.value__ -ne 0) {
    Write-Host "! ERROR: $name installer contained a digital signature, but it was invalid."
    Write-Host "  This strongly suggests that the file has been tampered with."
    Write-Host "  Please re-attempt download. If the issue persists, contact Support."
    exit 1
  }

  $varIntermediate = ($varChain.ChainElements | ForEach-Object { $_.Certificate } | Where-Object { $_.Subject -match "$certificate" }).Thumbprint
  if ($varIntermediate -ne $thumbprint) {
    Write-Host "! ERROR: $file did not pass verification checks for its digital signature."
    Write-Host "  This could suggest that the certificate used to sign the $name installer"
    Write-Host "  has changed; it could also suggest tampering in the connection chain."
    Write-Host `r
    if ($varIntermediate) {
      Write-Host ": We received: $varIntermediate"
      Write-Host "  We expected: $thumbprint"
      Write-Host "  Please report this issue."
    } else {
      Write-Host "  The installer's certificate authority has changed."
    }
    Write-Host "- Installation cannot continue. Exiting."
    exit 1
  } else {
    Write-Host ": Digital Signature verification passed."
  }
}

function writeLog {
  param(
    [int]$MessageType,
    [string]$Message
  )
  if ($MessageType -eq 1) {
    Write-Error -Message "ERROR: $Message"
  } else {
    Write-Host "$Message" -ForegroundColor Green
  }
}

# endregion functions

# -- If no ProductIDs supplied, show GUI --
if ($ProductIDs.Count -eq 0 -or $null -eq $ProductIDs) {
  $ProductIDs = Show-ProductSelector
  if ($null -eq $ProductIDs) {
    Write-Host "Installation cancelled by user."
    exit 0
  }
}

# Validate again post-GUI (defensive)
if ($ProductIDs.Count -eq 0 -or $null -eq $ProductIDs) {
  writeLog -MessageType 1 -Message "ProductIDs cannot be empty!"
  exit 1
}

if (-not (Test-Path -Path $TempDir)) {
  New-Item -Path $TempDir -ItemType Directory | Out-Null
}

# Download the ODT page to get the latest link.
downloadFile "https://www.microsoft.com/en-us/download/details.aspx?id=49117" "www.microsoft.com" "$ODTLinkHtmlPath"
$varLink = ((Get-Content "$ODTLinkHtmlPath").split('"') | Select-String 'exe' | Select-String 'download.microsoft.com' | Select-Object -First 1).ToString()

# Download ODT, then verify the certificate
downloadFile $varLink "https://download.microsoft.com" "$OD_exe"
verifyPackage "$OD_exe" "Microsoft Windows Code Signing PCA 2024" "D30F05F637E605239C0070D1EA9860D434AC2A94" "Microsoft Office Deployment Tool" "https://download.microsoft.com"

# Build the XML document used to configure ODT.
$XMLHead = @"
<Configuration ID="0cde0183-63ba-4508-b386-4a2bda99ec3f">
  <Add OfficeClientEdition="64" Channel="$UpdateChannel">
"@
$XMLFoot = @"
</Add>
<Updates Enabled="TRUE" />
<RemoveMSI />
<AppSettings>
  <Setup Name="Company" Value="$CompanyName" />
</AppSettings>
<Display Level="Full" AcceptEULA="TRUE" />
</Configuration>
"@

$ProductIDsXML = ""
foreach ($id in $ProductIDs) {
  $ProductIDsXML += @"
    <Product ID="$id">
      <Language ID="$Language" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
    </Product>
"@
}

$ODT_XML = $XMLHead + $ProductIDsXML + $XMLFoot
Set-Content -Path "$OD_XML_PATH" -Force -Value "$ODT_XML"

# Run ODT, then call setup.exe with the provided XML
Start-Process "$OD_exe" -ArgumentList "/extract:`"$TempDir`" /log:`"$TempDir\OfficeInstall.log`" /quiet /norestart" -Wait
Start-Process "$OD_Setup_exe" -ArgumentList "/configure `"$OD_XML_PATH`"" -Wait