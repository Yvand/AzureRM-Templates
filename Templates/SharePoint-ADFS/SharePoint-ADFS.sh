location="west europe"
resourceGroupName="ydcli"
adminUserName="yvand"
adminPassword=ChangeYourAdminPassword1

az group create --name $resourceGroupName --location "$location"

# Create network security groups
az network nsg create --name "NSG-VNet-DC" -g $resourceGroupName
az network nsg rule create -g $resourceGroupName --nsg-name "NSG-VNet-DC" --name "allow-rdp-rule" --priority 100 --source-address-prefixes Internet \
    --source-port-ranges "*" --destination-address-prefixes '*' --destination-port-ranges 3389 --access Allow --protocol Tcp --description "Allow RDP"

az network nsg create --name "NSG-VNet-SQL" -g $resourceGroupName
az network nsg rule create -g $resourceGroupName --nsg-name "NSG-VNet-SQL" --name "allow-rdp-rule" --priority 100 --source-address-prefixes Internet \
    --source-port-ranges "*" --destination-address-prefixes '*' --destination-port-ranges 3389 --access Allow --protocol Tcp --description "Allow RDP"

az network nsg create --name "NSG-VNet-SP" -g $resourceGroupName
az network nsg rule create -g $resourceGroupName --nsg-name NSG-VNet-SP --name "allow-rdp-rule" --priority 100 --source-address-prefixes Internet \
    --source-port-ranges "*" --destination-address-prefixes '*' --destination-port-ranges 3389 --access Allow --protocol Tcp --description "Allow RDP"

# Create virtual network
az network vnet create -g $resourceGroupName --address-prefixes 10.0.0.0/16 --name Vnet
az network vnet subnet create -g $resourceGroupName --vnet-name Vnet --name "Subnet-DC" --address-prefixes 10.0.1.0/24 --network-security-group "NSG-VNet-DC"
az network vnet subnet create -g $resourceGroupName --vnet-name Vnet --name "Subnet-SQL" --address-prefixes 10.0.2.0/24 --network-security-group "NSG-VNet-SQL"
az network vnet subnet create -g $resourceGroupName --vnet-name Vnet --name "Subnet-SP" --address-prefixes 10.0.3.0/24 --network-security-group "NSG-VNet-SQL"

# # Create a VM
az network public-ip create --allocation-method Dynamic --name pip_dc -g $resourceGroupName
az network nic create --name nic_dc --public-ip-address pip_dc --vnet-name Vnet --subnet Subnet-DC -g $resourceGroupName
az vm create --resource-group $resourceGroupName --name DC --image win2016datacenter --admin-username $adminUserName --admin-password $adminPassword --license-type Windows_Server \
    --nics nic_dc --os-disk-size-gb 128 --os-disk-caching ReadWrite --os-disk-name "vm_dc_osdisk" --size Standard_F4

az vm extension set --name DSC --publisher Microsoft.Powershell --version 2.19 --vm-name DC -g $resourceGroupName \
   --settings '{"ModulesURL":"https://github.com/Azure/azure-quickstart-templates/raw/master/dsc-extension-iis-server-windows-vm/ContosoWebsite.ps1.zip", "configurationFunction": "ContosoWebsite.ps1\\ContosoWebsite", "Properties": {"MachineName": "myVM"} }'

# az find subnet