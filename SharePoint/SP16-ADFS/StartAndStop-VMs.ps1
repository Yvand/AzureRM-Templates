### Shutdown VMs
{
Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name "SP" -Force
Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name "SQL" -Force
Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name "DC" -Force
}

### Start VMs
{
Start-AzureRmVM -ResourceGroupName $resourceGroupName -Name "DC"
Start-AzureRmVM -ResourceGroupName $resourceGroupName -Name "SQL"
Start-AzureRmVM -ResourceGroupName $resourceGroupName -Name "SP"
}
