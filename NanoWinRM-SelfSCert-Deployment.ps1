  <#
  .SYNOPSIS
  Configuring a Azure Nano Server for HTTPS WinRM Connection.
  
  .DESCRIPTION
  This script will create a local self signed certificate, upload that cerfificate into Nano Server, configure Nano server's WinRM for HTTPS and then clean up. 
  
  .EXAMPLE
  NanoWinRM-SelfSCert-Deployment.ps1 -VMName nanodemovm1 -DNSlabelName nanodemovm1 -RGName nano-demo -SubscriptionId 5ab198c5-3475-4f18-8f0d-b0c6267dad58

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
  File Name  : NanoWinRM-SelfSCert-Deployment.ps1
  Author     : Hannel Hazeley - hhazeley@outlook.com
  Version    : 1.0
  Requires   : Azure PowerShell 3.0 and higher, Windows 10 or Windwos Server 2016

  .LINK
  Demo: https://youtu.be/mzD2MaIwb2o
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
Login-AzureRmAccount -ErrorAction Stop | Out-Null
Select-AzureRmSubscription -SubscriptionId $SubscriptionId

#Get VM. create DNS Label and Vaultname
$VM = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName -ErrorAction Stop
$DNSLabel = $DNSlabelName+"."+$VM.Location+".cloudapp.azure.com"

#Creating Cert in Locally and updating to share
$securefile = Get-Content .\securefile.txt
$StorageA = $securefile[0]
$StorageAAK = $securefile[1]
$password = $securefile[2]
$Cert = New-SelfSignedCertificate -DnsName "$DNSLabel" -CertStoreLocation "cert:\LocalMachine\My" -FriendlyName $DNSlabelName -NotAfter (Get-Date).AddMonths(60)
$thumbprint = $Cert.Thumbprint
Export-PfxCertificate -Cert $cert -Password (ConvertTo-SecureString "$password" -AsPlainText -Force) -FilePath .\$DNSlabelName.pfx -Force
$ctx=New-AzureStorageContext $StorageA $StorageAAK
New-AzureStorageShare cert -Context $ctx -ErrorAction SilentlyContinue
$s = Get-AzureStorageShare cert -Context $ctx
Set-AzureStorageFileContent -Share $s -Source .\$DNSlabelName.pfx -Force

#Updating FireWall and WinRM using Custom Script extension
$args = "$StorageA $StorageAAK $DNSlabelName $password $DNSLabel $Thumbprint"
Set-AzureRmVMCustomScriptExtension -ResourceGroupName $rgName -VMName $vmName -Argument $args -FileUri https://hazelnestpublicstore.blob.core.windows.net/public/WinRMHTTPS-FCSC-Set.ps1 -Location $VM.Location -Name WinRMHTTPS-FCSC-Set -Run WinRMHTTPS-FCSC-Set.ps1 -ErrorAction Stop -Verbose

#Cleanup
Remove-AzureRmVMExtension -Name WinRMHTTPS-FCSC-Set -ResourceGroupName $rgName -VMName $vmName -Force -Verbose