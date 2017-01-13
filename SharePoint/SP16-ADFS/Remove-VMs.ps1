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
$blobStorageContainer = "vhds"
$vmsToDelete = @("SP", "SQL", "DC")
#$vmsToDelete = @("DC")
Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroupName -StorageAccountName $StorageAccountName 
Get-AzureRmContext

ForEach ($vmToDelete in $vmsToDelete) {
#$vmsToDelete| Foreach-Object -Process {
    #$vmToDelete = $_
    $disksNames = @()
    $vm = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmToDelete
    $disksNames+=$vm.StorageProfile.OsDisk.Name
    #$vm.StorageProfile.DataDisks| %{$disksNames+=$_.Vhd.Uri}
    $disksNames+=$vm.DataDiskNames
    
    Write-Host "Removing VM $vmToDelete..."
    Remove-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmToDelete -Force

    #Get-AzureStorageContainer -Name $blobStorageContainer | Get-AzureStorageBlob | ft Name
    $disksNames| Foreach-Object -Process {
        Write-Host "Removing disk $_..."
        Remove-AzureStorageBlob -Container $blobStorageContainer -Blob $_".vhd"
    }
    Write-Host "VM $vmToDelete deleted."
}
Write-Host "Finished."
