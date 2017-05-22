$resourceGroupName = 'YD-SP16ADFS-2VM'
$resourceGroupName = 'xxYD-SP16ADFS-2VM'
$azurecontext = $null
$azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
if ($azurecontext -eq $null) {
    Login-AzureRmAccount
    $azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
}
if ($azurecontext -eq $null){ 
    Write-Host "Unable to get a valid context." -ForegroundColor Red
    return
}

### Shutdown VMs
{
Write-Output "Stopping FE..."
Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name "FE" -Force
Write-Output "Stopping SP..."
Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name "SP" -Force
Write-Output "Stopping SQL..."
Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name "SQL" -Force
Write-Output "Stopping DC..."
Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name "DC" -Force
}

### Start VMs
{
Write-Output "Starting DC..."
Start-AzureRmVM -ResourceGroupName $resourceGroupName -Name "DC"
Write-Output "Starting SQL..."
Start-AzureRmVM -ResourceGroupName $resourceGroupName -Name "SQL"
Write-Output "Starting SP..."
Start-AzureRmVM -ResourceGroupName $resourceGroupName -Name "SP"
Write-Output "Starting FE..."
Start-AzureRmVM -ResourceGroupName $resourceGroupName -Name "FE"
}
