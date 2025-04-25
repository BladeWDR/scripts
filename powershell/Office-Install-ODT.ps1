<#
  .SYNOPSIS
  Downloads O365 using ODT.
  .DESCRIPTION
  Script to automate the downloading of Microsoft Office 365 using the Office Deployment Tool.
  .PARAMETER ProductID
  Sets which product will be installed. Defaults to Office 365 apps for business. https://learn.microsoft.com/en-us/microsoft-365/troubleshoot/installation/product-ids-supported-office-deployment-click-to-run
  .PARAMETER UpdateChannel
  Sets the update channel. Defaults to MonthlyEnterprise. https://learn.microsoft.com/en-us/microsoft-365-apps/deploy/office-deployment-tool-configuration-options#channel-attribute-part-of-updates-element
  .PARAMETER MatchOS
  Sets the default Language. Defaults to match operating system. https://learn.microsoft.com/en-us/microsoft-365-apps/deploy/overview-deploying-languages-microsoft-365-apps#languages-culture-codes-and-companion-proofing-languages
#>

param(
  [string]$ProductID = "O365BusinessRetail",
  [string]$UpdateChannel = "MonthlyEnterprise",
  [string]$LanguageID = "MatchOS"
)

$TEMPDIR = 'C:\Temp'
$DOWNLOADPATH = "$TEMPDIR\odt.exe"
$ODTXMLPATH = "$TEMPDIR\odtscript.xml"
$ODTEXEPATH = "$TEMPDIR\setup.exe"

# Scrape the current ODT download link since there's no static link for it.
$htmlContent = Invoke-WebRequest -Uri "https://www.microsoft.com/en-us/download/details.aspx?id=49117"
$regex = '"url":"(https://download\.microsoft\.com/download/[^\s"]+\.exe)"'
if ($htmlContent.Content -match $regex)
{
  $downloadUrl = $matches[1]
  Write-Host "Setting download URI to $downloadUrl"
  $DOWNLOAD_URL = $downloadUrl
} else
{
  Write-Error "Download URL not found. Microsoft may have broken something."
  exit 1
}

# Get needed information like Company Name.

$COMPANY_NAME = Read-Host 'Please enter your company name'

if ([String]::IsNullorWhitespace($COMPANY_NAME))
{
  $COMPANY_NAME = "Office"
}

$CONFIG = @"
<Configuration ID="0cde0183-63ba-4508-b386-4a2bda99ec3f">
  <Add OfficeClientEdition="64" Channel="$UpdateChannel">
    <Product ID="$ProductID">
      <Language ID="$LanguageID" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
    </Product>
  </Add>
  <Updates Enabled="TRUE" />
  <RemoveMSI />
  <AppSettings>
    <Setup Name="Company" Value="$COMPANY_NAME" />
  </AppSettings>
  <Display Level="Full" AcceptEULA="TRUE" />
</Configuration>
"@

if (-not (Test-Path -Path "$TEMPDIR" -PathType Container))
{
  New-Item -Path "TEMPDIR" -Type Directory
}


if (-not (Test-Path -Path $DOWNLOADPATH -PathType Leaf))
{
  try
  {
    Write-Host "Downloading Office Deployment Toolkit..."
    Invoke-WebRequest -Uri "$DOWNLOAD_URL" -Out "$DOWNLOADPATH" | Out-Null
    Write-Host "Downloaded Office Deployment Toolkit successfully."
  } catch
  {
    Write-Host "Error downloading Office Deployment Toolkit from Microsoft. $_"
    exit 1
  }
}
# Extract the Office Deployment Tool
Write-Host "Extracting ODT setup.exe..."
start-process -FilePath "$DOWNLOADPATH" -ArgumentList "/extract:C:\temp","/quiet","/norestart" -Wait

# Create the target xml file
Set-Content -Path "$ODTXMLPATH" -Force -Value $CONFIG

Write-Host "Downloading Office 365 cab files. This could take a few minutes..."
Start-Process -FilePath "$ODTEXEPATH" -ArgumentList "/download $ODTXMLPATH" -WorkingDirectory "$TEMPDIR" -Wait

Write-Host "Installing Office, please wait..."
Start-Process -FilePath "$ODTEXEPATH" -ArgumentList "/configure $ODTXMLPATH" -WorkingDirectory "$TEMPDIR" -Wait
