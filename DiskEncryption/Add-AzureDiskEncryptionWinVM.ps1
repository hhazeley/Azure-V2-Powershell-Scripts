  <#
  .SYNOPSIS
  Adds disk encryption to a Windows Azure Virtual Machine
  
  .DESCRIPTION
  This script will deploy disk encryption with key vault key encryption (KEK) to a Windows Azure Virtual Machine 
  
  .EXAMPLE
  Initialize-AzureDiskEncryption.ps1 -SubscriptionId 1d6737e7-4f6c-4e3c-8cd4-996b6f003d0e -AADAppName DiskE -vaultRGName DiskE -vaultName DiskE-vault -Location westus

  .PARAMETER SubscriptionId
  Subscription ID for the subscription where the Azure Key Vault will be created. Required

  .PARAMETER vmName
  The name of the virtual machine to be encrypted. Required

  .PARAMETER rgName
  The Resource Group the virtual machine that will be encrypted belongs to. Required

  .PARAMETER aadClientID
  The application ID for the Azure Active Directory Application that will be used, make sure you have secret for application. Required

  .PARAMETER kvResourceID
  The Azure Key Vault resource ID where the secret and encryption key (KEK) are stored. Required

  .PARAMETER kvKeyURL
  The URL for the Azure Key Vault encryption key (KEK) to be used. Required

  .PARAMETER kvSecretURL
  The URL for the Azure Key Vault secret to be used. Required


  .NOTES
  File Name  : Add-AzureDiskEncryptionWinVM.ps1
  Author     : Hannel Hazeley - hhazeley@outlook.com
  Version    : 1.0
  Requires   : Azure PowerShell 3.5 or higher

  .LINK
  https://docs.microsoft.com/en-us/azure/security/azure-security-disk-encryption
  http://hazelnest.com/blog/blog/tag/disk-encryption/
  #>

[cmdletbinding()]
Param (
    [Parameter(Mandatory=$true)]
    $SubscriptionId,
    [Parameter(Mandatory=$true)]
    $vmName,
    [Parameter(Mandatory=$true)]
    $rgName,
    [Parameter(Mandatory=$true)]
    $aadClientID,
    [Parameter(Mandatory=$true)]
    $kvResourceID,
    [Parameter(Mandatory=$true)]
    $kvKeyURL,
    [Parameter(Mandatory=$true)]
    $kvSecretURL
)

$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"

#Function for error checks
Function ErrorCheck{
If ($errorck -ne $null)
{
Write-host
Write-host -ForegroundColor Red "ERROR: " -NoNewline
Write-Host -ForegroundColor Red $errorck
Write-Host
Write-Host "______________________________________________________________________"
Write-Host -ForegroundColor Red "Script aborted, see above error. Please take manual rollback steps if needed"
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

#Requesting AAD client secret 
Write-Host
$password = Read-Host -assecurestring "Enter AAD Client Secret"
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$aadClientSecret = $UnsecurePassword

#Adding certificate from key vault to VM
Write-Host -ForegroundColor Green "Uploading Key Vault PFX certificate to VM $vmName"
$vm = Get-azureRmVM -ResourceGroupName $rgname -Name $vmName -ErrorVariable errorck
ErrorCheck
$hout = Add-AzureRmVMSecret -VM $vm -SourceVaultId $kvResourceID -CertificateStore "My" -CertificateUrl $kvSecretURL -ErrorVariable errorck
ErrorCheck
Update-AzureRmVM -ResourceGroupName $rgname -VM $vm -ErrorVariable errorck
ErrorCheck

#Enabling Azure Disk Encryption using extension
Write-Host -ForegroundColor Green "You are about to add disk encryption to VM $vmName, this will take about 10 - 15 minutes the VM will reboot during this process. " -NoNewline
Write-Host -ForegroundColor Red "Press any key to continue ..." -NoNewline
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host
Write-Host -ForegroundColor Green "Adding encryption to VM  $vmName ......."
$kvURL = $kvSecretURL -Replace "Secrets/.*",""
Set-AzureRmVMDiskEncryptionExtension -AadClientID $aadClientID -AadClientSecret $aadClientSecret `
-DiskEncryptionKeyVaultId $kvResourceID -DiskEncryptionKeyVaultUrl $kvURL `
-ResourceGroupName $rgName -VMName $vmName -KeyEncryptionKeyUrl $kvKeyURL -KeyEncryptionKeyVaultId $kvResourceID -Force -ErrorVariable errorck
ErrorCheck