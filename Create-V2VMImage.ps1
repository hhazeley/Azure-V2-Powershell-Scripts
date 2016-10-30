  <#
  .SYNOPSIS
  Creates V2 Virtual machine image 
  
  .DESCRIPTION
  This script will generalize virtual machine and creates image from a viurtual machine that should have been sysperep.  
  Please remember after running this script you can no longer use virtual machine as it will b e in a generalize state. 
  
  .EXAMPLE
  Create-V2VMImage.ps1 -SubscriptionId 1d6737e7-4f6c-4e3c-8cd4-996b6f003d0e -ResourceGroupName DVideoRG1 -StorageAccountName DVStore1 -VMName DV1-DPBIMG-001 -VHDNamePrefix DVImage

  Generalize virtual machine and creates and image of machine to be used for later deployment. 
      
  .PARAMETER SubscriptionId
  Subscription ID for the subscription that virtual machine is on. Required
    
  .PARAMETER ResourceGroupName
  The Resource Group the virtual machine belongs to. Required

  .PARAMETER StorageAccountName
  The name of the storage account were virtual machine is stored. Required

  .PARAMETER VMName
  The name of the virtual machine you need to create image from to be deleted. Required

  .PARAMETER VHDNamePrefix
  VHDNamePrefix is used to identify the image, This can be anything. Required


  .NOTES
  File Name  : Create-V2VMImage.ps1
  Author     : Hannel Hazeley - hhazeley@outlook.com

  .LINK
  https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-capture-image/
  http://hazelnest.com/blog/blog/2016/10/12/dv1-series-azure-02-create-deploy-image/

  #>

 Param(
    [Parameter(Mandatory=$true)]
    $SubscriptionId,
    [Parameter(Mandatory=$true)]
    $ResourceGroupName,
    [Parameter(Mandatory=$true)]
    $StorageAccountName,
    [Parameter(Mandatory=$true)]
    $VMName,
    [Parameter(Mandatory=$true)]
    $VHDNamePrefix
   )


#Login to Azure and select subscription
Login-AzureRmAccount
Select-AzureRmSubscription -SubscriptionId $SubscriptionId

#Stop VM 
Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force

#Generalize VM and confirm status
Set-AzureRmVm -ResourceGroupName $ResourceGroupName -Name $VMName -Generalized
$vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -status
$vm.Statuses

#Create Azure VM Image 
Save-AzureRmVMImage -ResourceGroupName $ResourceGroupName -VMName $VMName -DestinationContainerName $ResourceGroupName.ToLower() -VHDNamePrefix $VHDNamePrefix

#Getting Image VHD URI
$SA  = Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName
$image = ($SA | Get-AzureStorageBlob -Container "system").Name | ?{$_ -like "*$VHDNamePrefix-osDisk*.vhd"}
$imageURI = "https://$StorageAccountName.blob.core.windows.net/system/$Image"

$imageURI 
