<#
.DESCRIPTION to install Office 365 products using the Office Deployment Toolkit.
.PARAMETER ProductIDs - a comma separated list of Product IDs to install.
.PARAMETER UpdateChannel - Optional Parameter to specify the update channel. Defaults to Current.
.PARAMETER Language - Defaults to MatchOS.
.PARAMETER CompanyName - Defaults to "Office".
#>

param(
  [string[]]$ProductIDs,
  [string]$UpdateChannel='Current',
  [string]$Language='MatchOS',
  [string]$CompanyName='Office'
)

# Force TLS1.2
[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)

# region vars

$TempDir = "C:\temp"
$ODTLinkHtmlPath = "$TempDir\ODTLink.html"
$OD_Setup_exe = "$TempDir\setup.exe"
$OD_exe="$TempDir\ODTool.exe"
$OD_XML_PATH="$TempDir\365config.xml"

# region functions
function downloadFile
{ #downloadFile, build 32/seagull :: copyright datto, inc. :: MODIFIED VERSION; tls 1.2 happens on line 20

  param (
    [parameter(mandatory=$false)]$url,
    [parameter(mandatory=$false)]$whitelist,
    [parameter(mandatory=$false)]$filename,
    [parameter(mandatory=$false,ValueFromPipeline=$true)]$pipe
  )

  function setUserAgent
  {
    $script:WebClient = New-Object System.Net.WebClient
    $script:webClient.UseDefaultCredentials = $true
    $script:webClient.Headers.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f")
    $script:webClient.Headers.Add([System.Net.HttpRequestHeader]::UserAgent, 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705;)');
  }

  if (!$url)
  {$url=$pipe
  }
  if (!$whitelist)
  {$whitelist="the required web addresses."
  }
  if (!$filename)
  {$filename=$url.split('/')[-1]
  }

  write-host "- Downloading: $url"
  setUserAgent
  $script:webClient.DownloadFile("$url","$filename")

  if (!(test-path $filename))
  {
    write-host "- ERROR: File $filename could not be downloaded."
    write-host "  Please ensure you are whitelisting $whitelist."
    write-host "- Operations cannot continue; exiting."
    exit 1
  } else
  {
    write-host "- Downloaded:  $filename"
  }
}

function verifyPackage ($file, $certificate, $thumbprint, $name, $url)
{ #verifyPackage build 4/seagull :: datto/kaseya
  if (!(test-path "$file"))
  {
    write-host "! ERROR: Downloaded file could not be found."
    write-host "  Please ensure firewall access to $url."
    exit 1
  }

  #construct chain
  $varChain=New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
  try
  {
    $varChain.Build((Get-AuthenticodeSignature -FilePath "$file").SignerCertificate) | out-null
  } catch [System.Management.Automation.MethodInvocationException]
  {
    write-host "! ERROR: $name installer did not contain a valid digital certificate."
    write-host "  This could suggest a change in the way $name is packaged; it could"
    write-host "  also suggest tampering in the connection chain."
    write-host "- Please ensure $url is whitelisted and try again."
    write-host "  If this issue persists across different devices, please file a support ticket."
    exit 1
  }
  #check digsig status
  if ((Get-AuthenticodeSignature "$file").status.value__ -ne 0)
  {
    write-host "! ERROR: $name installer contained a digital signature, but it was invalid."
    write-host "  This strongly suggests that the file has been tampered with."
    write-host "  Please re-attempt download. If the issue persists, contact Support."
    exit 1
  }

  #inspect certificate thumbprints "$Message" -ForegroundColor Green
  $varIntermediate=($varChain.ChainElements | % { $_.Certificate} | ? {$_.Subject -match "$certificate"}).Thumbprint
  if ($varIntermediate -ne $thumbprint)
  {
    write-host "! ERROR: $file did not pass verification checks for its digital signature."
    write-host "  This could suggest that the certificate used to sign the $name installer"
    write-host "  has changed; it could also suggest tampering in the connection chain."
    write-host `r
    if ($varIntermediate)
    {
      write-host ": We received: $varIntermediate"
      write-host "  We expected: $thumbprint"
      write-host "  Please report this issue."
    } else
    {
      write-host "  The installer's certificate authority has changed."
    }
    write-host "- Installation cannot continue. Exiting."
    exit 1
  } else
  {
    write-host ": Digital Signature verification passed."
  }
}

function writeLog
{
  param(
    [int]$MessageType,
    [string]$Message
  )

  if ($MessageType -eq 1)
  {
    Write-Error -Message "ERROR: $Message"
  } else
  {
    Write-Host "$Message" -ForegroundColor Green
  }
}

if (-not (Test-Path -Path $TempDir))
{
  new-item -path "$TempDir" -ItemType Directory
}

if ($ProductIDs.count -eq 0 -or $null -eq $ProductIDs)
{
  writeLog -MessageType 1 -Message "ProductsIDs cannot be empty!"
  exit 1
}

# Download the ODT page to get the latest link.
downloadFile "https://www.microsoft.com/en-us/download/details.aspx?id=49117" "www.microsoft.com" "$ODTLinkHtmlPath"
$varLink=(get-content "$ODTLinkHtmlPath").split('"') | select-string 'exe' | select-string 'download.microsoft.com' | select-object -first 1

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
# Generate the ProductIDs section.
$ProductIDsXML=""
foreach ($id in $ProductIDs)
{
  $ProductIDsXML+= @"
   <Product IDs="$id">
   <Language ID="$Language" />
   <ExcludeApp ID="Groove" />
   <ExcludeApp ID="Lync" />
   </Product>
"@
}

# Concatenate the final XML document.
$ODT_XML=$XMLHead + $ProductIDsXML + $XMLFoot
Set-Content -Path "$OD_XML_PATH" -Force -Value "$ODT_XML"

# Run ODT, then call setup.exe with the provided XML
start-process "$OD_exe" -ArgumentList "/extract:`"$TempDir`" /log:`"$TempDir\OfficeInstall.log`" /quiet /norestart" -Wait
start-process "$OD_Setup_exe" -argumentlist "/configure `"$OD_XML_PATH`"" -Wait