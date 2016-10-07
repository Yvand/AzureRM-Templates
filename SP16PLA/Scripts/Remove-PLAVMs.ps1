#Script will remove all resources created by the deploy script

Param(
    [string] $ResourceGroupName = 'SPPLA_Arm_Test'
)

#Remove VM's
Find-AzureRmResource -TagName 'author' -TagValue 'sppla' | Where-Object {$_.ResourceType -eq 'Microsoft.Compute/virtualMachines' -and $_.ResourceGroupName -eq $ResourceGroupName} | Remove-AzureRmResource -Force -Confirm:$false

#Remove Availability Sets
Find-AzureRmResource -TagName 'author' -TagValue 'sppla' | Where-Object {$_.ResourceType -eq 'Microsoft.Compute/availabilitySets' -and $_.ResourceGroupName -eq $ResourceGroupName } | Remove-AzureRmResource -Force -Confirm:$false

#Remove LB
Find-AzureRmResource -TagName 'author' -TagValue 'sppla' | Where-Object {$_.ResourceType -eq 'Microsoft.Network/loadBalancers' -and $_.ResourceGroupName -eq $ResourceGroupName } | Remove-AzureRmResource -Force -Confirm:$false

#Remove the nics
Find-AzureRmResource -TagName 'author' -TagValue 'sppla' | Where-Object {$_.ResourceType -eq 'Microsoft.Network/networkInterfaces' -and $_.ResourceGroupName -eq $ResourceGroupName } | Remove-AzureRmResource -Force -Confirm:$false

#Remove Storage Accounts
Find-AzureRmResource -TagName 'author' -TagValue 'sppla' | Where-Object {$_.ResourceType -eq 'Microsoft.Storage/storageAccounts' -and $_.ResourceGroupName -eq $ResourceGroupName } | Remove-AzureRmResource -Force -Confirm:$false

