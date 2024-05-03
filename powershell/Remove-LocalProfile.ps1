# Removes local user profiles in Windows.
# Replace 'username' with the actual username of the domain user whose profile you want to delete
$username = Read-Host "Enter username"

# Construct the path to the user profile folder
$profilePath = "C:\Users\$username"

# Check if the profile folder exists
if (Test-Path $profilePath) {
    # Remove the profile folder
    Remove-Item -Path $profilePath -Recurse -Force
    Write-Output "User profile for $username deleted successfully."
} else {
    Write-Output "User profile for $username not found."
}

# Look for the user profile registry keys.
$keys = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" | Select-Object -ExpandProperty Name

foreach ($key in $keys) {
    $path = (Get-ItemProperty -Path "Registry::$key").ProfileImagePath
    if ($path -eq $profilePath) {
        Write-Output "Matching profile found: $key"
        Remove-ItemProperty -Path "Registry::$key" -Name ProfileImagePath
        Write-Output "ProfileImagePath deleted from $key"
        break # Exit the loop once a match is found
    }
}
