location="west europe"
resourceGroupName="ydcli"
adminUserName="yvand"
adminPassword=ChangeYourAdminPassword1
artifactsURI="https://github.com/Yvand/AzureRM-Templates/raw/master/Templates/SharePoint-ADFS/"
domainFQDN="contoso.local"
adfsSvcUserName="svc_adfs"
sqlSvcUserName="svc_sql"
spSetupUserName="spsetup"

az group create --name $resourceGroupName --location "$location"

# Create network security groups
az network nsg create --name "NSG-VNet-DC" -g $resourceGroupName
az network nsg rule create -g $resourceGroupName --nsg-name "NSG-VNet-DC" --name "allow-rdp-rule" --priority 100 --source-address-prefixes Internet \
    --source-port-ranges "*" --destination-address-prefixes '*' --destination-port-ranges 3389 --access Allow --protocol Tcp --description "Allow RDP"

az network nsg create --name "NSG-VNet-SQL" -g $resourceGroupName
az network nsg rule create -g $resourceGroupName --nsg-name "NSG-VNet-SQL" --name "allow-rdp-rule" --priority 100 --source-address-prefixes Internet \
    --source-port-ranges "*" --destination-address-prefixes '*' --destination-port-ranges 3389 --access Allow --protocol Tcp --description "Allow RDP"

az network nsg create --name "NSG-VNet-SP" -g $resourceGroupName
az network nsg rule create -g $resourceGroupName --nsg-name "NSG-VNet-SP" --name "allow-rdp-rule" --priority 100 --source-address-prefixes Internet \
    --source-port-ranges "*" --destination-address-prefixes '*' --destination-port-ranges 3389 --access Allow --protocol Tcp --description "Allow RDP"

# Create virtual network
az network vnet create -g $resourceGroupName --address-prefixes 10.0.0.0/16 --name Vnet
az network vnet subnet create -g $resourceGroupName --vnet-name Vnet --name "Subnet-DC" --address-prefixes 10.0.1.0/24 --network-security-group "NSG-VNet-DC"
az network vnet subnet create -g $resourceGroupName --vnet-name Vnet --name "Subnet-SQL" --address-prefixes 10.0.2.0/24 --network-security-group "NSG-VNet-SQL"
az network vnet subnet create -g $resourceGroupName --vnet-name Vnet --name "Subnet-SP" --address-prefixes 10.0.3.0/24 --network-security-group "NSG-VNet-SQL"
az network vnet subnet create -g $resourceGroupName --vnet-name Vnet --name "BastionSubnet" --address-prefixes 10.0.4.0/24

# Create VM DC
az network public-ip create --allocation-method Dynamic --name PublicIP-DC --dns-name "${resourceGroupName}-dc" -g $resourceGroupName
az network nic create --name VM-DC-NIC --public-ip-address PublicIP-DC --vnet-name Vnet --subnet Subnet-DC -g $resourceGroupName
az vm create --resource-group $resourceGroupName --name DC --image win2016datacenter --admin-username $adminUserName --admin-password $adminPassword --license-type Windows_Server \
    --nics VM-DC-NIC --os-disk-size-gb 128 --os-disk-caching ReadWrite --os-disk-name "VM-DC-OSDisk" --size Standard_F4

az vm extension set --name DSC --publisher Microsoft.Powershell --version 2.9 --vm-name DC -g $resourceGroupName \
   --settings '{"ModulesURL": "'${artifactsURI}'dsc/ConfigureDCVM.zip", "configurationFunction": "ConfigureDCVM.ps1\\ConfigureDCVM", "Properties": {"domainFQDN": "'${domainFQDN}'", "PrivateIP": "10.0.1.4"} }' \
   --protected-settings '{"Properties": {"AdminCreds": {"UserName": "'${adminUserName}'", "Password": "'${adminPassword}'" }, "AdfsSvcCreds": {"UserName": "'${adfsSvcUserName}'", "Password": "'${adminPassword}'" }}}'

# # Create VM SQL
az network public-ip create --allocation-method Dynamic --name PublicIP-SQL --dns-name "${resourceGroupName}-sql" -g $resourceGroupName
az network nic create --name VM-SQL-NIC --public-ip-address PublicIP-SQL --vnet-name Vnet --subnet Subnet-SQL -g $resourceGroupName
az vm create --resource-group $resourceGroupName --name SQL --image MicrosoftSQLServer:SQL2019-WS2016:SQLDEV:15.0.190910 --admin-username $adminUserName --admin-password $adminPassword \
    --nics VM-SQL-NIC --os-disk-size-gb 128 --os-disk-caching ReadWrite --os-disk-name "VM-SQL-OSDisk" --size Standard_F4
az vm update --name SQL -g $resourceGroupName --license-type Windows_Server --no-wait

az vm extension set --name DSC --publisher Microsoft.Powershell --version 2.9 --vm-name SQL -g $resourceGroupName \
   --settings '{"ModulesURL": "'${artifactsURI}'dsc/ConfigureSQLVM.zip", "configurationFunction": "ConfigureSQLVM.ps1\\ConfigureSQLVM", "Properties": {"domainFQDN": "'${domainFQDN}'", "DNSServer": "10.0.1.4"} }' \
   --protected-settings '{"Properties": {"DomainAdminCreds": {"UserName": "'${adminUserName}'", "Password": "'${adminPassword}'" }, "SqlSvcCreds": {"UserName": "'${sqlSvcUserName}'", "Password": "'${adminPassword}'" }, "SPSetupCreds": {"UserName": "'${spSetupUserName}'", "Password": "'${adminPassword}'" }}}'
az vm extension set --name SqlIaaSAgent --publisher "Microsoft.SqlServer.Management" --version 2.0 --vm-name SQL -g $resourceGroupName --no-wait
