#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -u: immediately exit if using a variable not previously declared
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0 -g <resourceGroupName> -l <resourceGroupLocation> -p <accountsPassword>" 1>&2; exit 1; }

location="west europe"
resourceGroupName="ydcli"
adminUserName="yvand"
adminPassword=""
serviceAccountsPassword=$adminPassword
artifactsURI="https://github.com/Yvand/AzureRM-Templates/raw/master/Templates/SharePoint-ADFS/"
domainFQDN="contoso.local"
adfsSvcUserName="svc_adfs"
sqlSvcUserName="svc_sql"
spSetupUserName="spsetup"
spFarmUserName="svc_spfarm"
spSvcUserName="svc_svcfarm"
spAppPoolUserName="svc_spapppool"
spPassphrase=$adminPassword
spSuperUserName="svc_spSuperUser"
spSuperReaderName="svc_spSuperReader"

# Initialize parameters specified from command line
while getopts ":i:g:n:l:" arg; do
	case "${arg}" in
		g)
			resourceGroupName=${OPTARG}
			;;
		l)
			resourceGroupLocation=${OPTARG}
			;;
        p)
			adminPassword=${OPTARG}
			;;
		esac
done
shift $((OPTIND-1))

if [[ -z "$resourceGroupName" ]]; then
	echo "This script will look for an existing resource group, otherwise a new one will be created "
	echo "You can create new resource groups with the CLI using: az group create "
	echo "Enter a resource group name"
	read resourceGroupName
	[[ "${resourceGroupName:?}" ]]
fi

if [[ -z "$adminPassword" ]]; then
	echo "Enter a password"
	read -s adminPassword
	[[ "${adminPassword:?}" ]]
fi

az group show --name $resourceGroupName 1> /dev/null || 
{
	echo "Resource group with name $resourceGroupName could not be found. Creating new resource group.."
    (
        set -x
        az group create --name $resourceGroupName --location "$location" 1> /dev/null
    )
}

# Create network security groups if they do not exist
nsgNames=(
  "NSG-VNet-DC"
  "NSG-VNet-SQL"
  "NSG-VNet-SP"
)
for nsgName in ${nsgNames[@]}; do
    az network nsg show --name $nsgName --resource-group $resourceGroupName 1> /dev/null ||
    {
        echo "Network security group $nsgName could not be found, creating it..."
        (
            set -x
            az network nsg create --name $nsgName -g $resourceGroupName 1> /dev/null
            az network nsg rule create -g $resourceGroupName --nsg-name $nsgName --name "allow-rdp-rule" --priority 100 --source-address-prefixes Internet \
                --source-port-ranges "*" --destination-address-prefixes '*' --destination-port-ranges 3389 --access Allow --protocol Tcp --description "Allow RDP" 1> /dev/null
        )
    }
done

# Create virtual network if it does not exist
vnetName="Vnet"
if ! az network vnet show --name $vnetName -g $resourceGroupName 1> /dev/null; then
	echo "Virtual network name $vnetName could not be found, creating it..."
	(
	    set -x
		az network vnet create --name Vnet -g $resourceGroupName --address-prefixes 10.0.0.0/16 1> /dev/null
        az network vnet subnet create -g $resourceGroupName --vnet-name Vnet --name "Subnet-DC" --address-prefixes 10.0.1.0/24 --network-security-group "NSG-VNet-DC" 1> /dev/null
        az network vnet subnet create -g $resourceGroupName --vnet-name Vnet --name "Subnet-SQL" --address-prefixes 10.0.2.0/24 --network-security-group "NSG-VNet-SQL" 1> /dev/null
        az network vnet subnet create -g $resourceGroupName --vnet-name Vnet --name "Subnet-SP" --address-prefixes 10.0.3.0/24 --network-security-group "NSG-VNet-SQL" 1> /dev/null
        az network vnet subnet create -g $resourceGroupName --vnet-name Vnet --name "AzureBastionSubnet" --address-prefixes 10.0.4.0/24 1> /dev/null
	)
	else
	echo "Use existing virtual network $vnetName."
fi

# Create VM DC if it does not exist
if ! az vm show --resource-group $resourceGroupName --name DC 1> /dev/null; then
    echo "Virtual machine DC could not be found, creating it.."
	(
	    set -x
		az network public-ip create --allocation-method Dynamic --name PublicIP-DC --dns-name "${resourceGroupName}-dc" -g $resourceGroupName 1> /dev/null
        az network nic create --name VM-DC-NIC --public-ip-address PublicIP-DC --vnet-name Vnet --subnet Subnet-DC -g $resourceGroupName 1> /dev/null
        az vm create --resource-group $resourceGroupName --name DC --image win2016datacenter --admin-username $adminUserName --admin-password $adminPassword --license-type Windows_Server \
            --nics VM-DC-NIC --os-disk-size-gb 128 --os-disk-caching ReadWrite --os-disk-name "VM-DC-OSDisk" --size Standard_F4 1> /dev/null

        az vm extension set --name DSC --publisher Microsoft.Powershell --version 2.9 --vm-name DC -g $resourceGroupName \
            --settings '{"ModulesURL": "'${artifactsURI}'dsc/ConfigureDCVM.zip", "configurationFunction": "ConfigureDCVM.ps1\\ConfigureDCVM", "Properties": {"domainFQDN": "'${domainFQDN}'", "PrivateIP": "10.0.1.4"} }' \
            --protected-settings '{"Properties": {"AdminCreds": {"UserName": "'${adminUserName}'", "Password": "'${adminPassword}'" }, "AdfsSvcCreds": {"UserName": "'${adfsSvcUserName}'", "Password": "'${adminPassword}'" }}}' 1> /dev/null
	)
	else
	echo "Virtual machine DC already exists and was not modified."
fi

# Create VM SQL if it does not exist
if ! az vm show --resource-group $resourceGroupName --name SQL 1> /dev/null; then
    echo "Virtual machine SQL could not be found, creating it.."
	(
	    set -x
		az network public-ip create --allocation-method Dynamic --name PublicIP-SQL --dns-name "${resourceGroupName}-sql" -g $resourceGroupName 1> /dev/null
        az network nic create --name VM-SQL-NIC --public-ip-address PublicIP-SQL --vnet-name Vnet --subnet Subnet-SQL -g $resourceGroupName 1> /dev/null
        az vm create --resource-group $resourceGroupName --name SQL --image MicrosoftSQLServer:SQL2017-WS2016:SQLDEV:latest --admin-username $adminUserName --admin-password $adminPassword \
            --nics VM-SQL-NIC --os-disk-size-gb 128 --os-disk-caching ReadWrite --os-disk-name "VM-SQL-OSDisk" --size Standard_DS2_v2 1> /dev/null
        az vm extension set --name DSC --publisher Microsoft.Powershell --version 2.9 --vm-name SQL -g $resourceGroupName \
            --settings '{"ModulesURL": "'${artifactsURI}'dsc/ConfigureSQLVM.zip", "configurationFunction": "ConfigureSQLVM.ps1\\ConfigureSQLVM", "Properties": {"domainFQDN": "'${domainFQDN}'", "DNSServer": "10.0.1.4"} }' \
            --protected-settings '{"Properties": {"DomainAdminCreds": {"UserName": "'${adminUserName}'", "Password": "'${adminPassword}'" }, "SqlSvcCreds": {"UserName": "'${sqlSvcUserName}'", "Password": "'${serviceAccountsPassword}'" }, "SPSetupCreds": {"UserName": "'${spSetupUserName}'", "Password": "'${serviceAccountsPassword}'" }}}' 1> /dev/null
        az vm update --name SQL -g $resourceGroupName --license-type Windows_Server --no-wait 1> /dev/null
        # az vm extension set --name SqlIaaSAgent --publisher "Microsoft.SqlServer.Management" --version 2.0 --vm-name SQL -g $resourceGroupName --no-wait 1> /dev/null
	)
	else
	echo "Virtual machine SQL already exists and was not modified."
fi

# Create VM SP if it does not exist
if ! az vm show --resource-group $resourceGroupName --name SP 1> /dev/null; then
    echo "Virtual machine SP could not be found, creating it.."
	(
	    set -x
		az network public-ip create --allocation-method Dynamic --name PublicIP-SP --dns-name "${resourceGroupName}-sp" -g $resourceGroupName 1> /dev/null
        az network nic create --name VM-SP-NIC --public-ip-address PublicIP-SP --vnet-name Vnet --subnet Subnet-SP -g $resourceGroupName 1> /dev/null
        az vm create --resource-group $resourceGroupName --name SP --image MicrosoftSharePoint:MicrosoftSharePointServer:2019:latest --admin-username $adminUserName --admin-password $adminPassword \
            --nics VM-SP-NIC --os-disk-size-gb 128 --os-disk-caching ReadWrite --os-disk-name "VM-SP-OSDisk" --size Standard_DS3_v2 1> /dev/null
        az vm extension set --name DSC --publisher Microsoft.Powershell --version 2.9 --vm-name SP -g $resourceGroupName \
            --settings '{"ModulesURL": "'${artifactsURI}'dsc/ConfigureSPVM.zip", "configurationFunction": "ConfigureSPVM.ps1\\ConfigureSPVM", "Properties": {"domainFQDN": "'${domainFQDN}'", "DNSServer": "10.0.1.4", "DCName": "DC", "SQLName": "SQL", "SQLAlias": "SQLAlias", "SharePointVersion": "2019"} }' \
            --protected-settings '{"Properties": {"DomainAdminCreds": {"UserName": "'${adminUserName}'", "Password": "'${adminPassword}'" }, "SPSetupCreds": {"UserName": "'${spSetupUserName}'", "Password": "'${serviceAccountsPassword}'" }, "SPFarmCreds": {"UserName": "'${spFarmUserName}'", "Password": "'${serviceAccountsPassword}'" }, "SPSvcCreds": {"UserName": "'${spSvcUserName}'", "Password": "'${serviceAccountsPassword}'" }, "SPAppPoolCreds": {"UserName": "'${spAppPoolUserName}'", "Password": "'${serviceAccountsPassword}'" }, "SPPassphraseCreds": {"UserName": "'${spPassphrase}'", "Password": "'${spPassphrase}'" }, "SPSuperUserCreds": {"UserName": "'${spSuperUserName}'", "Password": "'${serviceAccountsPassword}'" }, "SPSuperReaderCreds": {"UserName": "'${spSuperReaderName}'", "Password": "'${serviceAccountsPassword}'" }}}' 1> /dev/null
        az vm update --name SP -g $resourceGroupName --license-type Windows_Server --no-wait 1> /dev/null
	)
	else
	echo "Virtual machine SP already exists and was not modified."
fi
