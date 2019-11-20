"""Create SharePoint environment

This script expects that the following environment vars are set:

AZURE_TENANT_ID: your Azure Active Directory tenant id or domain
AZURE_CLIENT_ID: your Azure Active Directory Application Client ID
AZURE_CLIENT_SECRET: your Azure Active Directory Application Secret
AZURE_SUBSCRIPTION_ID: your Azure Subscription Id
"""
import os
import traceback
import json
from getpass import getpass

from azure.common.credentials import ServicePrincipalCredentials
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.compute.models import DiskCreateOption

from msrestazure.azure_exceptions import CloudError


LOCATION = 'westus'
GROUP_NAME = 'azurepy-ydspadfs'
SHAREPOINT_VERSION = '2019'
adminUserName = 'yvand'
adminPassword = ""
adminPassword = getpass()
artifactsURI="https://github.com/Yvand/AzureRM-Templates/raw/master/Templates/SharePoint-ADFS/"
domainFQDN="contoso.local"
adfsSvcUserName="svc_adfs"
sqlSvcUserName="svc_sql"
spSetupUserName="spsetup"
spFarmUserName="svc_spfarm"
spSvcUserName="svc_svcfarm"
spAppPoolUserName="svc_spapppool"
spSuperUserName="svc_spSuperUser"
spSuperReaderName="svc_spSuperReader"

DC_NAME = "DC"
SQL_NAME = "SQL"
SP_NAME = "SP"

NETWORK_REFERENCE = {
    "vNetPrivateName": GROUP_NAME + '-VNet',
    "vNetPrivatePrefix": "10.0.0.0/16",
    "vNetPrivateSubnetDCName": "Subnet-1",
    "vNetPrivateSubnetDCPrefix": "10.0.1.0/24",
    "vNetPrivateSubnetSQLName": "Subnet-2",
    "vNetPrivateSubnetSQLPrefix": "10.0.2.0/24",
    "vNetPrivateSubnetSPName": "Subnet-3",
    "vNetPrivateSubnetSPPrefix": "10.0.3.0/24",
}

VM_REFERENCE = {
    "dc": {
        "publisher": "MicrosoftWindowsServer",
        "offer": "WindowsServer",
        "sku": "2019-Datacenter",
        "version": "latest",
        "vmOSDiskName": "Disk-DC-OS",
        "vmVmSize": "Standard_F4",
        "vmName": DC_NAME,
        "vmOSDiskName": f"Disk-{DC_NAME}-OS",
        "vmPublicIPName": "PublicIP-" + DC_NAME,
        "vmPublicIPDnsName": (GROUP_NAME + "-" + DC_NAME).lower().replace("_", "-", -1),
        "vmNicName": f"NIC-{DC_NAME}-0",
        "nicPrivateIPAddress": "10.0.1.4"
    },
    "sql": {
        "publisher": "MicrosoftSQLServer",
        "offer": "SQL2017-WS2016",
        "sku": "SQLDEV",
        "version": "latest",
        "vmOSDiskName": "Disk-DC-OS",
        "vmVmSize": "Standard_D2_v2",
        "vmName": SQL_NAME,
        "vmOSDiskName": f"Disk-{SQL_NAME}-OS",
        "vmPublicIPName": "PublicIP-" + SQL_NAME,
        "vmPublicIPDnsName": (GROUP_NAME + "-" + SQL_NAME).lower().replace("_", "-", -1),
        "vmNicName": f"NIC-{SQL_NAME}-0"
    },
    "sp": {
        "publisher": "MicrosoftSharePoint",
        "offer": "MicrosoftSharePointServer",
        "sku": SHAREPOINT_VERSION,
        "version": "latest",
        "vmOSDiskName": "Disk-DC-OS",
        "vmVmSize": "Standard_D11_v2",
        "vmName": SP_NAME,
        "vmOSDiskName": f"Disk-{SP_NAME}-OS",
        "vmPublicIPName": "PublicIP-" + SP_NAME,
        "vmPublicIPDnsName": (GROUP_NAME + "-" + SP_NAME).lower().replace("_", "-", -1),
        "vmNicName": f"NIC-{SP_NAME}-0"
    }
}

def get_credentials():
    adminPassword = os.environ['ADMINPASSWORD']
    subscription_id = os.environ['AZURE_SUBSCRIPTION_ID']
    credentials = ServicePrincipalCredentials(
        client_id=os.environ['AZURE_CLIENT_ID'],
        secret=os.environ['AZURE_CLIENT_SECRET'],
        tenant=os.environ['AZURE_TENANT_ID']
    )
    return credentials, subscription_id

def create_template():
    credentials, subscription_id = get_credentials()
    resource_client = ResourceManagementClient(credentials, subscription_id)
    compute_client = ComputeManagementClient(credentials, subscription_id)
    network_client = NetworkManagementClient(credentials, subscription_id)

    # Create Resource group
    print('\nCreate Resource Group')
    resource_client.resource_groups.create_or_update(
        GROUP_NAME, {'location': LOCATION})
        
    """Create network
    """
    # Create network security groups
    print('\nCreate network security groups')
    nsg_parameter = {
        'location': LOCATION,
        'securityRules': [
            {
                'name': 'allow-rdp-rule',
                'properties': {
                    'description': 'Allow RDP',
                    'protocol': 'Tcp',
                    'sourcePortRange': '*',
                    'destinationPortRange': '3389',
                    'sourceAddressPrefix': 'Internet',
                    'destinationAddressPrefix': '*',
                    'access': 'Allow',
                    'priority': 100,
                    'direction': 'Inbound',
                    'sourcePortRanges': [],
                    'destinationPortRanges': [],
                    'sourceAddressPrefixes': [],
                    'destinationAddressPrefixes': []
                }
            }
        ]
    }
    nsgNames = ["NSG-VNet-DC", "NSG-VNet-SQL", "NSG-VNet-SP"]
    for nsgName in nsgNames:
        print(f'\nCreate network security group {nsgName}')
        async_creation = network_client.network_security_groups.create_or_update(GROUP_NAME, nsgName, nsg_parameter)
        async_creation.wait()

    # Create VNet
    print('\nCreate Vnet')
    async_vnet_creation = network_client.virtual_networks.create_or_update(
        GROUP_NAME,
        NETWORK_REFERENCE['vNetPrivateName'],
        {
            'location': LOCATION,
            'address_space': {
                'address_prefixes': [NETWORK_REFERENCE['vNetPrivatePrefix']]
            }
        }
    )
    async_vnet_creation.wait()

    # Create Subnets
    print('\nCreate Subnet for DC')
    async_subnet_creation = network_client.subnets.create_or_update(
        GROUP_NAME,
        NETWORK_REFERENCE['vNetPrivateName'],
        NETWORK_REFERENCE['vNetPrivateSubnetDCName'],
        {'address_prefix': NETWORK_REFERENCE['vNetPrivateSubnetDCPrefix']}
    )
    subnet_info_dc = async_subnet_creation.result()

    print('\nCreate Subnet for SQL')
    async_subnet_creation = network_client.subnets.create_or_update(
        GROUP_NAME,
        NETWORK_REFERENCE['vNetPrivateName'],
        NETWORK_REFERENCE['vNetPrivateSubnetSQLName'],
        {'address_prefix': NETWORK_REFERENCE['vNetPrivateSubnetSQLPrefix']}
    )
    subnet_info_sql = async_subnet_creation.result()

    print('\nCreate Subnet for SP')
    async_subnet_creation = network_client.subnets.create_or_update(
        GROUP_NAME,
        NETWORK_REFERENCE['vNetPrivateName'],
        NETWORK_REFERENCE['vNetPrivateSubnetSPName'],
        {'address_prefix': NETWORK_REFERENCE['vNetPrivateSubnetSPPrefix']}
    )
    subnet_info_sp = async_subnet_creation.result()

    # Create public IP addresses
    pips_info = []
    for vm in VM_REFERENCE:
        vmJson = str(VM_REFERENCE[vm]).replace("\'", "\"")
        vmDetails = json.loads(vmJson)

        print(f'\nCreate public IP address for {vmDetails["vmName"]}')
        async_pip_creation = network_client.public_ip_addresses.create_or_update(
            GROUP_NAME,
            vmDetails['vmPublicIPName'],
            {'location': LOCATION, 'public_ip_allocation_method': 'Dynamic', 
            'dns_settings': {'domain_name_label': vmDetails['vmPublicIPDnsName']},
            'sku': {'name': 'Basic'}}
        )
        pips_info.append(async_pip_creation.result())

    # Create VM DC
    print('\nCreate VM DC')
    print('Create NIC')
    print(f'pips_info[0].id: {pips_info[0].id}')
    async_nic_creation = network_client.network_interfaces.create_or_update(
        GROUP_NAME,
        VM_REFERENCE["dc"]["vmNicName"],
        {
            'location': LOCATION,
            'ip_configurations': [{
                'name': 'ipconfig1',
                'private_ip_allocation_method': 'Static',
                'private_ip_address': '10.0.1.4',
                'subnet': {
                    'id': subnet_info_dc.id
                },
                'public_ip_address': pips_info[0]
            }]
        }
    )
    async_nic_creation_result = async_nic_creation.result()

    print('Create virtual machine')
    vm_parameters = create_vm_parameters(async_nic_creation_result.id, VM_REFERENCE['dc'])
    async_vm_creation = compute_client.virtual_machines.create_or_update(
        GROUP_NAME, DC_NAME, vm_parameters)
    async_vm_creation.wait()


def create_vm_parameters(nic_id, vm_reference):
    """Create the VM parameters structure.
    """
    return {
        'location': LOCATION,
        'os_profile': {
            'computer_name': vm_reference['vmName'],
            'admin_username': adminUserName,
            'admin_password': adminPassword,
            'windows_configuration': {
                'provision_vm_agent': True,
                'enable_automatic_updates': True,
                'time_zone': 'Romance Standard Time'
            }
        },
        'hardware_profile': {
            'vm_size': 'Standard_DS1_v2'
        },
        'storage_profile': {
            'image_reference': {
                'publisher': vm_reference['publisher'],
                'offer': vm_reference['offer'],
                'sku': vm_reference['sku'],
                'version': vm_reference['version']
            },
            'os_disk': {
                'name': vm_reference['vmOSDiskName'],
                'caching': 'ReadWrite',
                'os_type': 'Windows',
                'create_option': 'FromImage',
                'disk_size_gb': 128,
                'managed_disk': {
                    'storage_account_type': 'Standard_LRS'
                }
            }
        },
        'network_profile': {
            'network_interfaces': [{
                'id': nic_id,
            }]
        },
        'license_type': 'Windows_Server'
    }

def tests():
    # for vm in VM_REFERENCE:
    #     vmJson = str(VM_REFERENCE[vm]).replace("\'", "\"")
    #     #VM_REFERENCE[vm]['vmName']
    #     #vmDetails = json.JSONDecoder.decode(VM_REFERENCE[vm])
    #     print(vmJson)
    #     vmDetails = json.loads(vmJson)
    #     type(vmDetails)

    #     print(f'\nTEST {vmDetails["vmName"]}')
    #     #vmDetails.get().

    print(f'\nTEST {VM_REFERENCE["dc"]["nicPrivateIPAddress"]}')
    pips_info = []
    pips_info.append("item1")
    pips_info.append("item2")
    pips_info.append("item3")
    print(f'\nTEST {pips_info[0]}')

if __name__ == "__main__":
    create_template()
    # tests()
