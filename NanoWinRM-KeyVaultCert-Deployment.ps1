  <#
  .SYNOPSIS
  Configuring a Azure Nano Server for HTTPS WinRM Connection.
  
  .DESCRIPTION
  This script will create a certificate using Azure Key Vault, upload that cerfificate into Nano Server, configure Nano server's WinRM for HTTPS and then clean up. 
  
  .EXAMPLE
  NanoWinRM-KeyVaultCert-Deployment.ps1 -VMName nanodemovm1 -DNSlabelName nanodemovm1 -RGName nano-demo -SubscriptionId 5ab198c5-3475-4f18-8f0d-b0c6267dad58

  All paramaters are required for te script to complete successfully. 

  .PARAMETER VMName
  The name of the virtual machine to be configured for WinRM HTTPS. Required

  .PARAMETER DNSlabelName
  The DNS Label name will be used as the CN for the certificate that will be created.
    
  .PARAMETER RGName
  The Resource Group the virtual machine belongs to. Required
  
  .PARAMETER SubscriptionId
  Subscription ID for the subscription that virtual machine is on

  .NOTES
  File Name  : NanoWinRM-KeyVaultCert-Deployment.ps1
  Author     : Hannel Hazeley - hhazeley@outlook.com
  Version    : 1.0
  Requires   : Azure PowerShell 3.0 and higher

  .LINK
  Demo: https://youtu.be/IVZQq2h27po
  Repository: https://github.com/hhazeley/Azure-V2-Powershell-Scripts
  #>

Param(
    [Parameter(Mandatory=$true)]
    $VMName,
    [Parameter(Mandatory=$true)]
    $DNSlabelName,
    [Parameter(Mandatory=$true)]
    $RGName,
    [Parameter(Mandatory=$true)]
    $SubscriptionId
)

#Loging to Azure 
$Account = Login-AzureRmAccount -ErrorAction Stop
Select-AzureRmSubscription -SubscriptionId $SubscriptionId
$UPN = $Account.Context.Account.id

#Get VM. create DNS Label and Vaultname
$VM = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName -ErrorAction Stop
$DNSLabel = $DNSlabelName+"."+$VM.Location+".cloudapp.azure.com"
$vaultname = "cv"+ (Get-Date -Format yyyyMMddHHmmss)

#Creating Cert in KeyVault
New-AzureRmKeyVault -Location $VM.Location -ResourceGroupName $RGName -VaultName $vaultname -EnabledForDeployment -EnabledForDiskEncryption -EnabledForTemplateDeployment -ErrorAction Stop | Out-Null
Set-AzureRmKeyVaultAccessPolicy -UserPrincipalName $UPN  -VaultName $vaultname -PermissionsToCertificates all -PermissionsToKeys all -PermissionsToSecrets all -ResourceGroupName $rgName -ErrorAction stop | Out-Null
Start-Sleep -Seconds 30 -Verbose
$CertPolicy = New-AzureKeyVaultCertificatePolicy -SubjectName "CN=$DNSLabel" -IssuerName Self -ValidityInMonths 60 -ErrorAction stop
Add-AzureKeyVaultCertificate -VaultName $vaultname -Name $DNSlabelName -CertificatePolicy $CertPolicy -ErrorAction Stop | Out-Null
Start-Sleep -Seconds 120 -Verbose

#Setting Certificate variavles 
$Cert = Get-AzureKeyVaultCertificate -VaultName $vaultname -Name $DNSlabelName -ErrorAction Stop
$vault = Get-AzureRmKeyVault -VaultName $vaultname -ResourceGroupName $RGName -ErrorAction Stop
$thumbprint = $Cert.Thumbprint

#upload Certificate to VM
$vm.OSProfile.Secrets.Clear()
Add-AzureRmVMSecret -VM $VM -CertificateStore "My" -CertificateUrl $Cert.SecretId -SourceVaultId $vault.ResourceId -ErrorAction Stop | Out-Null
Update-AzureRmVM -VM $VM -ResourceGroupName $rgName -ErrorAction Stop -Verbose

#Updating FireWall and WinRM using Custom Script extension
$args = "$DNSLabel $Thumbprint"
Set-AzureRmVMCustomScriptExtension -ResourceGroupName $rgName -VMName $vmName -Argument $args -FileUri https://hazelnestpublicstore.blob.core.windows.net/public/WinRMHTTPS-FC-Set.ps1 -Location $VM.Location -Name WinRMHTTPS-FC-Set -Run WinRMHTTPS-FC-Set.ps1 -ErrorAction Stop -Verbose

#Cleanup
$VM = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName -ErrorAction Stop
$vm.OSProfile.Secrets.Clear()
Update-AzureRmVM -VM $VM -ResourceGroupName $rgName -ErrorAction Stop -Verbose
Remove-AzureRmVMExtension -Name WinRMHTTPS-FC-Set -ResourceGroupName $rgName -VMName $vmName -Force -Verbose
Remove-AzureKeyVaultCertificate -Name $DNSlabelName -VaultName $vaultname -Force -Verbose
Remove-AzureRmKeyVault -VaultName $vaultname -ResourceGroupName $RGName -Force -Verbose