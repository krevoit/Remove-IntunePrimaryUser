## Remove Primary User Script for Intune
Steps:
- Download the script
- Create an App registration in Intune and assign the Device.ReadWrite.All, DeviceManagementManagedDevices.ReadWrite.All and 
Directory.ReadWrite.All permissions. Then go to certificates and create a key. Keep this VERY secure.
- Fill in the tenant ID, app ID and secret at the top of the script.
- Go into the script and change the prefix to what you would like, eg "INTUNE" would remove the primary user of every device starting with INTUNE.
- Profit

You will need Microsoft Graph module (possibly the beta).

*Slightly inspired from: https://github.com/microsoftgraph/powershell-intune-samples/blob/master/ManagedDevices/Win10_PrimaryUser_Delete.ps1. However there was many errors in the script and deprecated authentication methods, so I had to recreate it.*