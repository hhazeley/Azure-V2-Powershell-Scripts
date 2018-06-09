#Create variables
$SubscriptionId = ""
$vmName =  ""
$vmSize = ""
$rgName = ""
$location = ""
$osDiskName = ""
$nicName = ""
$osVhdUri = ""
#$AvailabilitySetName = "" 

#Login to Azure
Login-AzureRmAccount

#Select subscription and storage account for session 
Select-AzureRmSubscription -SubscriptionId $SubscriptionId

#Set the VM name, size and an AvailabilitySet if applicable
#$AvailabilitySet = Get-AzureRmAvailabilitySet -ResourceGroupName $rgName -Name $AvailabilitySetName #if applicable
$vm = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize #-AvailabilitySetId $AvailabilitySet.Id #if applicable

#Getting and Attaching to existing NIC
$nic = Get-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $rgName
$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id

#Getting and Attaching existing OS Disk
$osDisk = New-AzureRmDisk -DiskName $osDiskName -Disk (New-AzureRmDiskConfig -AccountType Premium_LRS -Location $location -CreateOption Import -SourceUri $osVhdUri) -ResourceGroupName $rgName
$vm = Set-AzureRmVMOSDisk -VM $vm -ManagedDiskId $osDisk.Id -CreateOption Attach -Windows `
-DiskEncryptionKeyUrl "" `
-DiskEncryptionKeyVaultId "" `
-KeyEncryptionKeyUrl "" `
-KeyEncryptionKeyVaultId ""

#Create VM
New-AzureRmVM -ResourceGroupName $rgName -Location $location -VM $vm #-LicenseType "Windows_Server"