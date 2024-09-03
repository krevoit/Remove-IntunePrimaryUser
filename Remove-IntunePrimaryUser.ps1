# If there is an undefined error, it means the device is most likely Personal instead of Corporate.
# Define the Tenant ID, Client ID, and Client Secret
$TenantId = "TENANTID"
$ClientId = "CLIENTID"
$ClientSecret = "CLIENTSECRET"
# I gave the app Device.ReadWrite.All, DeviceManagementManagedDevices.ReadWrite.All, Directory.ReadWrite.All. If things still don't work try Group.Read.All.

# Get the access token from Microsoft Graph
$Body = @{
    grant_type    = "client_credentials"
    scope         = "https://graph.microsoft.com/.default"
    client_id     = $ClientId
    client_secret = $ClientSecret
}

$TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method Post -Body $Body
$AccessToken = $TokenResponse.access_token

$authHeader = @{
    'Content-Type'='application/json'
    'Authorization'="Bearer $AccessToken"
}

# Function to get Intune managed devices
function Get-Win10IntuneManagedDevices {
    [cmdletbinding()]
    param (
        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$deviceName
    )
    
    $graphApiVersion = "beta"
    try {
        if($deviceName) {
            $Resource = "deviceManagement/managedDevices?`$filter=deviceName eq '$deviceName'"
	        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)" 
            (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value
        } else {
            $Resource = "deviceManagement/managedDevices?`$filter=(((deviceType%20eq%20%27desktop%27)%20or%20(deviceType%20eq%20%27windowsRT%27)%20or%20(deviceType%20eq%20%27winEmbedded%27)%20or%20(deviceType%20eq%20%27surfaceHub%27)))"
	        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value
        }
	} catch {
		$ex = $_.Exception
        $errorResponse = $ex.Response.Content.ReadAsStringAsync().Result
        Write-Host "Response content:`n$errorResponse" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
		throw "Get-IntuneManagedDevices error"
	}
}

# Function to get the primary user for the Intune device
function Get-IntuneDevicePrimaryUser {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $deviceId
    )
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices"
	$uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)" + "/" + $deviceId + "/users"

    try {
        $primaryUser = Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get
        return $primaryUser.value."id"
	} catch {
		$ex = $_.Exception
        $errorResponse = $ex.Response.Content.ReadAsStringAsync().Result
        Write-Host "Response content:`n$errorResponse" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
		throw "Get-IntuneDevicePrimaryUser error"
	}
}

# Function to delete the primary user for the Intune device
function Delete-IntuneDevicePrimaryUser {
    [cmdletbinding()]
    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $IntuneDeviceId
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices('$IntuneDeviceId')/users/`$ref"
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Delete
	} catch {
		$ex = $_.Exception
        $errorResponse = $ex.Response.Content.ReadAsStringAsync().Result
        Write-Host "Response content:`n$errorResponse" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
		throw "Delete-IntuneDevicePrimaryUser error"
    }
}

# This is the prefix of the devices that you would like the primary user removed from.
# Get all devices that start with "MSL-"
$DeviceNamePrefix = "MSL-"

$Devices = Get-Win10IntuneManagedDevices | Where-Object { $_.deviceName -like "$DeviceNamePrefix*" }

foreach ($Device in $Devices) {
    $DeviceName = $Device.deviceName
    Write-Host "Processing device: $DeviceName"

    $IntuneDevicePrimaryUser = Get-IntuneDevicePrimaryUser -deviceId $Device.id

    if ($IntuneDevicePrimaryUser) {
        $DeleteIntuneDevicePrimaryUser = Delete-IntuneDevicePrimaryUser -IntuneDeviceId $Device.id

        if ($DeleteIntuneDevicePrimaryUser -eq "") {
            Write-Host "Primary user removed from device '$DeviceName'." -ForegroundColor Green
        }
    } else {
        Write-Host "No primary user found for device '$DeviceName'." -ForegroundColor Yellow
    }
}