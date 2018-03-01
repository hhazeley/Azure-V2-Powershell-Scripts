  <#
  .SYNOPSIS
  Setup resources for Azure Disk Encryption
  
  .DESCRIPTION
  This script will create the necessary resource for enabling Azure Disk Encryption on a subscription
  
  .EXAMPLE
  Initialize-AzureDiskEncryption.ps1 -SubscriptionId 5ab198c5-3475-4f18-8f0d-b0c6267dad58 -AADAppName DiskE -vaultrgName DiskERG -vaultName DiskE-Vault -Location westus -Prefix WebServers

  .PARAMETER SubscriptionId
  Subscription ID for the subscription where the Azure Key Vault will be created. Required

  .PARAMETER AADAppName
  The name of the Azure Active Directory Application that will be used or you want the process to create. Required

  .PARAMETER vaultrgName
  The Resource Group where the Azure Key Vault will be created. Required

  .PARAMETER vaultName
  The name of the Azure Key Vault that will be used or you want the process to create . Required

  .PARAMETER Prefix
  Unique identify for Certificate, Secret and Key, if not provided vault name will be used.

  .PARAMETER Location
  The Azure region where you want the Azure Key Vault to be created.


  .NOTES
  File Name  : Initialize-AzureDiskEncryption.ps1
  Author     : Hannel Hazeley - hhazeley@outlook.com
  Version    : 1.0
  Requires   : Windows PowerShell 5.1 and Azure PowerShell 3.5 or higher

  .LINK
  https://docs.microsoft.com/en-us/azure/security/azure-security-disk-encryption
  http://hazelnest.com/blog/blog/tag/disk-encryption/

  #>

[cmdletbinding()]
Param (
    [Parameter(Mandatory=$true)]
    $SubscriptionId,
    [Parameter(Mandatory=$true)]
    $AADAppName,
    [Parameter(Mandatory=$true)]
    $vaultrgName,
    [Parameter(Mandatory=$true)]
    $vaultName,
    [ValidateLength(4,15)]
    $Prefix,
    [ValidateSet('eastasia','southeastasia','centralus','eastus','eastus2','westus','northcentralus','southcentralus','northeurope','westeurope','japanwest','japaneast','brazilsouth','australiaeast','australiasoutheast','southindia','centralindia','westindia','canadacentral','canadaeast','uksouth','ukwest','westcentralus','westus2')]
    $Location
)

$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"

#Set location if not specified 
If ($location -eq $null)
{
$location = "westus"
}

#Function for error checks
Function ErrorCheck{
If ($errorck -ne $null)
{
Write-host
Write-host -ForegroundColor Red "ERROR: " -NoNewline
Write-Host -ForegroundColor Red $errorck
Write-Host
Write-Host "______________________________________________________________________"
Write-Host -ForegroundColor Red "Script aborted, see above error. Perform rollback actions if needed."
Write-Host "______________________________________________________________________"
Write-Host
Break
}
}

#Login to Azure 
$Account = Login-AzureRmAccount -ErrorAction Stop
$UPN = $Account.Context.Account.id

#Set subscription
$hout = Select-AzureRmSubscription -SubscriptionId $SubscriptionId -ErrorVariable errorck
ErrorCheck

Write-Host "______________________________________________________________________"
Write-Host -ForegroundColor Cyan "Starting deployment"
Write-Host "______________________________________________________________________"
Write-Host 

#Password for certificate and application secret
$password = Read-Host -assecurestring "Enter Password for certificate and App Secret"
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$aadClientSecret = $password

#heck for and/or creating AAD Application 
Write-Host -ForegroundColor Green "Checking for application '$aadAppName'"
$azureAdApplicationValidation = Get-AzureRmADApplication -IdentifierUri "https://$aadAppName" 
if ($azureAdApplicationValidation -eq $null)
{
Write-Host -ForegroundColor Green "Application not found in AAD, creating application '$aadAppName'"
$azureAdApplication = New-AzureRmADApplication -DisplayName "$aadAppName" -HomePage "https://$aadAppName" -IdentifierUris "https://$aadAppName" -Password $aadClientSecret -ErrorVariable errorck
ErrorCheck
$servicePrincipal = New-AzureRmADServicePrincipal –ApplicationId $azureAdApplication.ApplicationId -ErrorVariable errorck
ErrorCheck
}
Else
{
Write-Host -ForegroundColor  Yellow -BackgroundColor Black "Application '$aadAppName' found, adding key to existing application"
$azureAdApplication = $azureAdApplicationValidation
$hout = New-AzureRmADAppCredential -ApplicationId $azureAdApplication.ApplicationId.Guid -Password $aadClientSecret -ErrorVariable errorck
ErrorCheck
$servicePrincipal = Get-AzureRmADServicePrincipal -ServicePrincipalName $azureAdApplication.ApplicationId -ErrorVariable errorck
if ($servicePrincipal -eq $null)
{
$servicePrincipal = New-AzureRmADServicePrincipal –ApplicationId $azureAdApplication.ApplicationId -ErrorVariable errorck
ErrorCheck
}
}

#Check for and/or create Azure Key Vault
Write-Host -ForegroundColor Green "Checking for Key Vault '$vaultName'"
$vaultNameValidation = Get-AzureRmKeyVault -VaultName $vaultName
if ($vaultNameValidation -eq $null)
{
Write-Host -ForegroundColor Green "Key Vault '$vaultName' not found"
#Check for and/or created Azure Resource Group
$VaultrgNameValidation = Get-AzureRmResourceGroup -Name $VaultrgName 
if ($VaultrgNameValidation -eq $null)
{
Write-Host -ForegroundColor Green "Creating Resource Group '$VaultrgName' for Key Vault '$vaultName'"
$rg = New-AzureRmResourceGroup -Name $VaultrgName -location $location -Force -ErrorVariable errorck
ErrorCheck
}
Else
{
$rgLocation = $VaultrgNameValidation.Location
If ($rgLocation -ne $location)
{
Write-Host -ForegroundColor Yellow -BackgroundColor Black "Resource Group location is different from specified location, resource will be created using same location as Resource Group ($rgLocation)."
$location = $rgLocation
}
}
Write-Host -ForegroundColor Green "Creating Key Vault '$vaultName'"
New-AzureRmKeyVault -Location $Location -ResourceGroupName $VaultrgName -VaultName $vaultName -EnabledForDeployment -EnabledForDiskEncryption -EnabledForTemplateDeployment -ErrorAction Stop | Out-Null
Set-AzureRmKeyVaultAccessPolicy -UserPrincipalName $UPN  -VaultName $vaultname -PermissionsToCertificates all -PermissionsToKeys all -PermissionsToSecrets all -ResourceGroupName $VaultrgName -ErrorAction stop | Out-Null
Set-AzureRmKeyVaultAccessPolicy -VaultName $VaultName -ServicePrincipalName $azureAdApplication.ApplicationId -PermissionsToKeys 'WrapKey' -PermissionsToSecrets 'Set' -ResourceGroupName $VaultrgName -ErrorAction stop | Out-Null
Start-Sleep -Seconds 30 -Verbose
$kv = Get-AzureRmKeyVault -VaultName $vaultName -ResourceGroupName $VaultrgName -ErrorVariable errorck
ErrorCheck
}
Else
{
Write-Host -ForegroundColor  Yellow -BackgroundColor Black "Key Vault '$vaultName' found, vaultrgName and Location supplied will be ignored"
Write-Host -ForegroundColor  Yellow -BackgroundColor Black "Updating permissions on Key Vault '$vaultName'"
$VaultrgName = $vaultNameValidation.ResourceGroupName
Set-AzureRmKeyVaultAccessPolicy -UserPrincipalName $UPN  -VaultName $vaultname -PermissionsToCertificates all -PermissionsToKeys all -PermissionsToSecrets all -ResourceGroupName $VaultrgName -ErrorAction stop | Out-Null
Set-AzureRmKeyVaultAccessPolicy -VaultName $VaultName -ServicePrincipalName $azureAdApplication.ApplicationId -PermissionsToKeys 'WrapKey' -PermissionsToSecrets 'Set' -ResourceGroupName $VaultrgName -ErrorAction stop | Out-Null
Start-Sleep -Seconds 30 -Verbose
$kv = Get-AzureRmKeyVault -VaultName $vaultName -ErrorVariable errorck
ErrorCheck
}

#Setup Prefix and suffix for Certificate, Secret and Key names 
If ($Prefix -eq $null)
{
$uPrefix = $vaultName.ToLower()
}
else 
{
$uPrefix = $Prefix.ToLower()  
}
$Suffix = Get-Date -Format yyyyMMddHHmmss

#Creating and uploading self-signed certificate to Azure Key Vault
Write-Host -ForegroundColor Green "Creating Self-singed certificate"
$certName = $uPrefix+"-"+$Suffix+'.pfx'
$Cert = New-SelfSignedCertificate -Subject "CN=Disk Encryption Cert"  -CertStoreLocation "cert:\LocalMachine\My" -FriendlyName "$vaultName - Disk Encryption Cert" -NotAfter (Get-Date).AddMonths(60) -KeyAlgorithm RSA -KeyLength 2048 -Type Custom -ErrorVariable errorck
ErrorCheck
$hout = Export-PfxCertificate -Cert $cert -Password $password -FilePath .\$certName -Force

$certLocalPath = (Dir | ? {$_.Name -eq $certName}).FullName
$SecretName = $uPrefix+'-secret-'+$Suffix

Write-Host -ForegroundColor Green "Converting and uploading certificate to Key Vault Secret"
$flag = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
$collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection 
$collection.Import($certLocalPath, $UnsecurePassword, $flag)
$pkcs12ContentType = [System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12
$clearBytes = $collection.Export($pkcs12ContentType)
$fileContentEncoded = [System.Convert]::ToBase64String($clearBytes)
$secret = ConvertTo-SecureString -String $fileContentEncoded -AsPlainText –Force
$secretContentType = 'application/x-pkcs12'
$hout = Set-AzureKeyVaultSecret -VaultName $vaultName -Name $SecretName -SecretValue $Secret -ContentType $secretContentType -ErrorVariable errorck
ErrorCheck
Start-Sleep -Seconds 30 -Verbose
$kvSecret = Get-AzureKeyVaultSecret -VaultName $vaultName -Name $SecretName

#Creating Azure Key Vault Encryption Keys 
Write-Host -ForegroundColor Green "Generating an Azure Key Vault encryption key (KEK)"
$KeyName = $uPrefix+'-key-'+$Suffix
$hout = Add-AzureKeyVaultKey -Destination Software -Name $KeyName -VaultName $vaultName -ErrorVariable errorck
ErrorCheck
Start-Sleep -Seconds 30 -Verbose
$kvKey = Get-AzureKeyVaultKey -Name $KeyName -VaultName $vaultName

#Adding Resource lock for safety 
$hout = New-AzureRmResourceLock -LockLevel CannotDelete -LockName "Critical Information" -Scope $kv.ResourceId -Force -LockNotes "Holds Disk Encryption keys"

#Creating output to be used for VM encryption 
Write-Host
Write-Host 
Write-Host -ForegroundColor Cyan "Disk Encryption setup completed, use information below to encrypt Virtual Machine"
Write-Host 
Write-Host "AADClientID ="$azureAdApplication.ApplicationId.Guid
Write-Host "AADClientSecret = (Use password you supplied)"
Write-Host "kvResourceID ="$kv.ResourceId
Write-Host "kvURL ="$kv.vaulturi
Write-Host "kvKeyURL ="$kvKey.Id.Replace(":443","")
Write-Host "kvSecretURL ="$kvSecret.Id.Replace(":443","")
Write-Host
Write-Host "______________________________________________________________________"
Write-Host -ForegroundColor Cyan "Deployment Completed"
Write-Host "______________________________________________________________________"