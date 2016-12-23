Import-Module Azure -ErrorAction SilentlyContinue
$azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
if ($azurecontext -eq $null) {
    Login-AzureRmAccount
    $azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
}
$subscriptionId = $azurecontext.Subscription.SubscriptionId
$resourceGroupLocation = 'westeurope'
$resourceGroupName = 'yd-sp16adfs'
$StorageAccountName = "ydsp16adfsst0"
$vmName = "SQL"
$blobStorageContainer = "vhds"
Set-AzureRmCurrentStorageAccount –ResourceGroupName $resourceGroupName –StorageAccountName $StorageAccountName 
Get-AzureRmContext

$disksNames = @()
$sqLVM = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName
$disksNames+=$sqLVM.StorageProfile.OsDisk.Name
#$sqLVM.StorageProfile.DataDisks| %{$disksNames+=$_.Vhd.Uri}
$disksNames+=$sqLVM.DataDiskNames
$disksNames
Write-Host "Removing VM $vmName..."
Remove-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName -Force

#Get-AzureStorageContainer -Name $blobStorageContainer | Get-AzureStorageBlob | ft Name
$disksNames| Foreach-Object -Process {
    Write-Host "Removing disk $_..."
    Remove-AzureStorageBlob -Container $blobStorageContainer -Blob $_".vhd"
}
Write-Host "Finished."
