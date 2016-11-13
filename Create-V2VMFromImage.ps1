   <#
  .SYNOPSIS
  Creating virtual machine(s) from image with one line cmdlet.
  
  .DESCRIPTION
  This script will use Image created by the Save-AzureRMImage cmdlet to do deployment of a single or numerous virtual machines. Before running this script Resource Group, Storage Account and Virtual Netowrk should have been created.
  
  .EXAMPLE
  Create-V2VMFromImage.ps1 -SubscriptionId 1d6737e7-4f6c-4e3c-8cd4-996b6f003d0e -ResourceGroupName DVideoRG1 -VHDNamePrefix Dvideo -storageAccName dvideostore1 -VmSize Basic_A1 -NewvmNames "DV1-DPBSV1-001" -VNetName DVideoVNet1

  This will create virtual machine, use/create default NSG and use deafult VNet subnet
      
  .EXAMPLE
  Create-V2VMFromImage.ps1 -SubscriptionId 1d6737e7-4f6c-4e3c-8cd4-996b6f003d0e -ResourceGroupName DVideoRG1 -VHDNamePrefix Dvideo -storageAccName dvideostore1 -VmSize Basic_A1 -NewvmNames "DV1-DPBSV1-001","DV1-DPBSV1-002" -VNetName DVideoVNet1

  This will create 2 virtual machine, use/create default NSG and use deafult VNet subnet
    
  .EXAMPLE
  Create-V2VMFromImage.ps1 -SubscriptionId 1d6737e7-4f6c-4e3c-8cd4-996b6f003d0e -ResourceGroupName DVideoRG1 -VHDNamePrefix Dvideo -storageAccName dvideostore1 -VmSize Basic_A1 -NewvmNames "DV1-DPBSV1-001" -VNetName DVideoVNet1 -SubNetName DVideoVNet1-S1 -NSGName InternalOnly

  This will create virtual machine on a specific subnet and NSG
      
  .PARAMETER SubscriptionId
  Subscription ID for the subscription that virtual machine is on. Required
    
  .PARAMETER ResourceGroupName
  Resource Group the virtual machine belongs to. Required

  .PARAMETER VHDNamePrefix
  VHD Name prefix used when image was created using the Save-AzureRMImage cmdlet. Required

  .PARAMETER StorageAccName
  Storeage account name where the Image is and the Virtual Machine are going to be stored. Required

  .PARAMETER VmSize
  Size of the new virtual machine that is been created Example: Standard_A0 See information in link https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-sizes/. Required

  .PARAMETER NewvmNames
  Name or names of the virtual machine(s) to be created. Required

  .PARAMETER VNetName
  Name of the virtual network that virtual machine will be on. Required

  .PARAMETER SubNetName
  Specify a SubNet within the Virtual Network that you will like machine to be on. If not specified machine will be on the default (initial) SubNet.

  .PARAMETER NSGName
  Specify a NIC NSG that you will like machine to be on. If not specified a Windows default NSG will be used/created automatically.

  .SWITCH NoAuth
  When switch is present, script will skip prompting for Azure credential. Use this option only if you have already authenticated to Azure on this Powershell session.

  .NOTES
  File Name  : Create-V2VMFromImage.ps1
  Author     : Hannel Hazeley - hhazeley@outlook.com
  Version    : 2.0
  Requires   : Azure PowerShell 3.0 and higher

  .LINK
  https://???????//

  #>

 Param(
    [Parameter(Mandatory=$true)]
    $SubscriptionId,
    [Parameter(Mandatory=$true)]
    $ResourceGroupName,
    [Parameter(Mandatory=$true)]
    $VHDNamePrefix,
    [Parameter(Mandatory=$true)]
    $StorageAccName,
    [Parameter(Mandatory=$true)]
    $VmSize,
    [Parameter(Mandatory=$true)]
    $NewvmNames,
    [Parameter(Mandatory=$true)]
    $VNetName,
    $SubNetName,
    $NSGName,
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
Login-AzureRmAccount | Out-Null
}

#Selecting subscription
Select-AzureRmSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop

#Get the storage account where the uploaded image is stored
$storageAcc = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -AccountName $storageAccName -ErrorAction Stop

#Gertting Location from resource group
$Location = (Get-AzureRmResourceGroup -Name $ResourceGroupName).location

#Getting and validating VM Size provided 
$VVMsizes = (Get-AzureRmVMSize -Location $Location).Name
If ($VVMsizes -notcontains $VMsize)
{
Write-Host ""
Write-Host -ForegroundColor Red "VM Size is invalid, must contain a valid size name. Example: Standard_A0 See information in link https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-sizes/"
Write-Host ""
Break
}

#Getting existing VNet in resource group
$VVNet = (Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName).name
If ($VVnet -notcontains $VNetName)
{
Write-Host ""
Write-Host -ForegroundColor Red "VNet Name is invalid, you must use an exisiting VNet Name"
Write-Host ""
Break
}
Else 
{
#Setting VNet to existing VNet
$VNet = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName
If ($SubNetName -eq $null)
{
#Putting server in 1st subnet since no specified
$SubNet = $VNet.Subnets[0]
}
Else
{
#Validating SubNetName 
If ($VNet.Subnets.name -notcontains $SubNetName)
{
Write-Host ""
Write-Host -ForegroundColor Red "SubNet Name is invalid, you must use an exisiting SubNet Name or leave it blank to use default subnet"
Write-Host ""
Break
}
Else
{
#Getting exsisting Subnet
$SubNet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNet -Name $SubnetName
}
}
}

#Getting existing NSG in resource group
$VNetworkSecurityGroup = (Get-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName).Name
If ($NSGName -eq $null)
{
#Validating Default NSG exists 
If ($VNetworkSecurityGroup -notcontains "WindowsServer-Default")
{
#Creating Default Windows NSG
$NSGRule = New-AzureRmNetworkSecurityRuleConfig -Name default-allow-rdp -Access Allow -Description "Allowing RDP connection" -DestinationAddressPrefix * -DestinationPortRange 3389 -Direction Inbound -Priority 1000 -Protocol Tcp -SourceAddressPrefix * -SourcePortRange *
New-AzureRmNetworkSecurityGroup -Location $location -Name WindowsServer-Default -ResourceGroupName $ResourceGroupName -SecurityRules $NSGRule
}
#Setting NSG to windows default NSG, since its not provided
$nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name WindowsServer-Default
}
Else
{
#Validating NSG name provided is a valid NSG 
If ($VNetworkSecurityGroup -notcontains $NSGName)
{
Write-Host ""
Write-Host -ForegroundColor Red "Network Security Group (NSG) is invalid, you must use an exisiting NSG or leave it blank to use\Create default Windows NSG"
Write-Host ""
Break
}
Else
{
#Setting NSG to NSG name provided
$nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $NSGName
}
}

# Enter a new user name and password to use as the local administrator account for the remotely accessing the VM
$cred = Get-Credential -Message "Username and Password for you new Virtual Machine"

Foreach ($NewvmName in $Newvmnames)
{
#Set the VM name and size
$vmConfig = New-AzureRmVMConfig -VMName $NewvmName -VMSize $VmSize

#Set the Windows operating system configuration and add the NIC
$vm = Set-AzureRmVMOperatingSystem -VM $vmConfig -Windows -ComputerName $NewvmName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate

#Create a random 3 digit number
$rnum = Get-Random -Minimum 100 -Maximum 999

#Creating Public IP
$pipName = $NewvmName.ToLower() + $rnum
$pip = New-AzureRmPublicIpAddress -Name $pipName -Location $Location -ResourceGroupName $ResourceGroupName -AllocationMethod Dynamic

#Creating NIC 
$nicName = $NewvmName.ToLower() + $rnum
$nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName -Location $Location -PublicIpAddress $pip -Subnet $SubNet -NetworkSecurityGroup $nsg

#Adding NIC to VM variable 
$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id

#Create the OS disk URI
$diskdate = Get-Date -Format "yyyyMMdd-HHmmss"
$osDiskUri = '{0}vhds/{1}-{2}.vhd' -f $storageAcc.PrimaryEndpoints.Blob.ToString(), $NewvmName.ToLower(), "osDisk-$diskdate"

#Getting os disk image from storage account using image VHDNamePrefix
$Image = ($storageAcc | Get-AzureStorageBlob -Container "system").Name | ?{$_ -like "*$VHDNamePrefix-osDisk*.vhd"}
$ImageURI = "https://$storageAccName.blob.core.windows.net/system/$Image"

#Configure the OS disk to be created from the image
$vm = Set-AzureRmVMOSDisk -VM $vm -Name $NewvmName -VhdUri $osDiskUri -CreateOption fromImage -SourceImageUri $imageURI -Windows

#Getting data disk image from storage account using image VHDNamePrefix
$ImagedataDisks = ($storageAcc | Get-AzureStorageBlob -Container "system").Name | ?{$_ -like "*$VHDNamePrefix-dataDisk-*.vhd"}
$DataDiskCount = 0

#If multiple data disk created from image and attach to new VM
Foreach ($Imagedatadisk in $ImagedataDisks)
{
#Create the OS disk URI
$diskdate = Get-Date -Format "yyyyMMdd-HHmmss"
$dataDiskUri = '{0}vhds/{1}-{2}.vhd' -f $storageAcc.PrimaryEndpoints.Blob.ToString(), $NewvmName.ToLower(), "dataDisk-$DataDiskCount-$diskdate"

#Configure the OS disk to be created from the image
$DataImageURI = "https://$storageAccName.blob.core.windows.net/system/$Imagedatadisk"
$DataDiskSize = ($storageAcc | Get-AzureStorageBlob -Blob $Imagedatadisk -Container "system").Length |% {[math]::Truncate($_ / 1GB)}
$vm = Add-AzureRmVMDataDisk -CreateOption fromImage -Name "$NewvmName-DataDisk-$DataDiskCount-$diskdate" -VhdUri $dataDiskUri -VM $VM -SourceImageUri $DataImageURI -DiskSizeInGB $DataDiskSize -Lun $DataDiskCount
$DataDiskCount = $DataDiskCount + 1
}

#Create the new VM
New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $vm -Verbose -ErrorVariable VMNotCreated

#If VM creation fails, deleted resources already created.
if($VMNotCreated -ne $null)
{
Remove-AzureRmNetworkInterface -Name "$nicname" -ResourceGroupName $ResourceGroupName -Force -Verbose
Remove-AzureRmPublicIpAddress -Name "$pipName" -ResourceGroupName $ResourceGroupName -Force -Verbose
Write-Host ""
Write-Host -ForegroundColor Red "Deployment of Virtual Machine $NewvmName failed."
Write-Host ""
}
Else
{
Write-Host ""
Write-Host -ForegroundColor Green "Deployment of Virtual Machine $NewvmName completed."
Write-Host ""
}

}