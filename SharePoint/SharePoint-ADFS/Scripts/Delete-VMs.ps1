param(
    [string[]] $VMsToDelete = @("SP", "SQL", "DC"),
    [string] $ResourceGroupLocation = "westeurope",
    [string] $StorageAccountName = "ydsp16adfsst",
    [string] $BlobStorageContainer = "vhds"
)

<#
$ResourceGroupLocation = 'westeurope'
$resourceGroupName = 'ydsp16adfs'
$resourceGroupName = 'xydsp16adfs'
$StorageAccountName = "ydsp16adfsst"
$StorageAccountName = "xydsp16adfsst"
$BlobStorageContainer = "vhds"
$VMsToDelete = @("SP", "SQL", "DC")
$VMsToDelete = @("SP", "SQL")
#$VMsToDelete = @("SP")
#>

Import-Module Azure -ErrorAction SilentlyContinue
$azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
if ($azurecontext -eq $null) {
    Login-AzureRmAccount
    $azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
}

Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroupName -StorageAccountName $StorageAccountName 
Get-AzureRmContext

<#
.SYNOPSIS
Delete VMs specified and their virtual disks

.DESCRIPTION
De

.PARAMETER vmsToDelete
VMs to delete

.EXAMPLE
An example

.NOTES
General notes
#>
function Delete-VMs($VMsToDelete) {
    ForEach ($vmToDelete in $VMsToDelete) {
    #$VMsToDelete| Foreach-Object -Process {
        #$vmToDelete = $_
        $disksNames = @()
        $vm = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmToDelete
        $disksNames += $vm.StorageProfile.OsDisk.Name
        $vm.StorageProfile.DataDisks| %{$disksNames += $_.Name}
        
        Write-Output "Removing VM $vmToDelete..."
        Remove-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmToDelete -Force

        #Get-AzureStorageContainer -Name $BlobStorageContainer | Get-AzureStorageBlob | ft Name
        $disksNames| Foreach-Object -Process {
            Write-Output "Removing disk $_..."
            Remove-AzureStorageBlob -Container $BlobStorageContainer -Blob $_".vhd"
        }
        Write-Output "VM $vmToDelete deleted."
    }
}

Delete-VMs $VMsToDelete
Write-Output "Finished."
