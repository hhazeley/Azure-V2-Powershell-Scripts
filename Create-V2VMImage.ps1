  <#
  .SYNOPSIS
  Creates V2 Virtual machine image 
  
  .DESCRIPTION
  This script will generalize virtual machine and creates image from a virtual machine that should have been sysprep.  
  Please remember after running this script you can no longer use virtual machine as it will b e in a generalize state. 
  
  .EXAMPLE
  Create-V2VMImage.ps1 -SubscriptionId 1d6737e7-4f6c-4e3c-8cd4-996b6f003d0e -rgName DVideoRG1 -StorageAccountName DVStore1 -VMName DV1-DPBIMG-001 -VHDNamePrefix DVImage

  Generalize virtual machine and creates and image of machine to be used for later deployment. 
      
  .PARAMETER SubscriptionId
  Subscription ID for the subscription that virtual machine is on. Required
    
  .PARAMETER rgName
  The Resource Group the virtual machine belongs to. Required

  .PARAMETER StorageAccountName
  The name of the storage account were virtual machine is stored. Required

  .PARAMETER VMName
  The name of the virtual machine you need to create image from to be deleted. Required

  .PARAMETER VHDNamePrefix
  VHDNamePrefix is used to identify the image, This can be anything. Required

  .SWITCH NoAuth
  When switch is present, script will skip prompting for Azure credential. Use this option only if you have already authenticated to Azure on this Powershell session.


  .NOTES
  File Name  : Create-V2VMImage.ps1
  Author     : Hannel Hazeley - hhazeley@outlook.com
  Version    : 2.0
  Requires   : Azure PowerShell 3.0 and higher

  .LINK
  https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-capture-image/
  http://hazelnest.com/blog/blog/2016/10/12/dv1-series-azure-02-create-deploy-image/

  #>

 Param(
    [Parameter(Mandatory=$true)]
    $SubscriptionId,
    [Parameter(Mandatory=$true)]
    $rgName,
    [Parameter(Mandatory=$true)]
    $StorageAccountName,
    [Parameter(Mandatory=$true)]
    $VMName,
    [Parameter(Mandatory=$true)]
    $VHDNamePrefix,
    [Switch]$NoAuth
   )


if ($NoAuth.IsPresent)
{
Write-Host ""
Write-Host -ForegroundColor Yellow "Skipping Login in to Azure"
Write-Host ""
}
Else
{
#Login into Azure
Login-AzureRmAccount -ErrorAction Stop | Out-Null
}

#Selecting subscription
Select-AzureRmSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop

#Stop VM 
Stop-AzureRmVM -ResourceGroupName $rgName -Name $VMName -Force -Verbose -ErrorAction Stop

#Generalize VM and confirm status
Set-AzureRmVm -ResourceGroupName $rgName -Name $VMName -Generalized | Out-Null
$vm = Get-AzureRmVM -ResourceGroupName $rgName -Name $VMName -status
$vm.Statuses

#Create Azure VM Image 
Save-AzureRmVMImage -ResourceGroupName $rgName -VMName $VMName -DestinationContainerName $VHDNamePrefix.ToLower() -VHDNamePrefix $VHDNamePrefix.ToLower() -ErrorAction Stop | Out-Null

#Getting Image VHD URI
Write-Host ""
Write-Host -ForegroundColor Green "VHD image created from virtual machine $vmname."
Write-Host ""
$SA  = Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $rgName
$image = ($SA | Get-AzureStorageBlob -Container "system").Name | ?{$_ -like "*$VHDNamePrefix-osDisk*.vhd"}
$imageURI = "https://$StorageAccountName.blob.core.windows.net/system/$Image"

$imageURI 
