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
import sys

from azure.common.credentials import ServicePrincipalCredentials
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.compute.models import DiskCreateOption
from msrestazure.azure_exceptions import CloudError

LOCATION = 'westeurope'
GROUP_NAME = 'azurepy-spadfs'
SHAREPOINT_VERSION = '2019'
ADMIN_USERNAME = 'yvand'
# ADMIN_PASSWORD = ""
# SERVICE_ACCOUNT_PASSWORD = ""
# ADMIN_PASSWORD = getpass()
# SERVICE_ACCOUNT_PASSWORD = ADMIN_PASSWORD
ARTIFACTS_URI = "https://github.com/Yvand/AzureRM-Templates/raw/master/Templates/SharePoint-ADFS/"
DOMAIN_FQDN = "contoso.local"
ADFS_SVC_USERNAME = "svc_adfs"
SQL_SVC_USERNAME = "svc_sql"
SP_SETUP_SVC_USERNAME = "spsetup"
SP_FARM_USERNAME = "svc_spfarm"
SP_SVC_USERNAME = "svc_svcfarm"
SP_APPPOOL_USERNAME = "svc_spapppool"
SP_SUPERUSER_NAME = "svc_spSuperUser"
SP_SUPERREADER_NAME = "svc_spSuperReader"
DC_NAME = "DC"
SQL_NAME = "SQL"
SP_NAME = "SP"
SQL_ALIAS = "SQLAlias"

PASSWORDS = {
    "ADMIN_PASSWORD" : "",
    "SERVICE_ACCOUNT_PASSWORD" : ""
}

NSG_PARAMETER = {
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

VM_DSC_REFERENCE = {
    "dc": {
        'location': LOCATION,
        'force_update_tag': '1.0',
        'publisher': 'Microsoft.Powershell',
        'virtual_machine_extension_type': 'DSC',
        'type_handler_version': '2.9',
        'auto_upgrade_minor_version': True,
        'settings': {
            'wmfVersion': 'latest',
            'configuration': {
                'url': ARTIFACTS_URI + 'dsc/ConfigureDCVM.zip',
                'script': 'ConfigureDCVM.ps1',
                'function': 'ConfigureDCVM'
            },
            'configurationArguments': {
                'DomainFQDN': DOMAIN_FQDN,
                'PrivateIP': VM_REFERENCE["dc"]["nicPrivateIPAddress"]
            },
            'privacy': {
                'dataCollection': 'enable'
            }
        },
        'protected_settings': {
            'configurationArguments': {
                'AdminCreds': {
                    'UserName': ADMIN_USERNAME,
                    'Password': '%(ADMIN_PASSWORD)'
                },
                'AdfsSvcCreds': {
                    'UserName': ADFS_SVC_USERNAME,
                    'Password': '%(SERVICE_ACCOUNT_PASSWORD)'
                }
            }
        }
    },
    "sql": {
        'location': LOCATION,
        'force_update_tag': '1.0',
        'publisher': 'Microsoft.Powershell',
        'virtual_machine_extension_type': 'DSC',
        'type_handler_version': '2.9',
        'auto_upgrade_minor_version': True,
        'settings': {
            'wmfVersion': 'latest',
            'configuration': {
                'url': ARTIFACTS_URI + 'dsc/ConfigureSQLVM.zip',
                'script': 'ConfigureSQLVM.ps1',
                'function': 'ConfigureSQLVM'
            },
            'configurationArguments': {
                'DNSServer': VM_REFERENCE["dc"]["nicPrivateIPAddress"],
                'DomainFQDN': DOMAIN_FQDN
            },
            'privacy': {
                'dataCollection': 'enable'
            }
        },
        'protected_settings': {
            'configurationArguments': {
                'DomainAdminCreds': {
                    'UserName': ADMIN_USERNAME,
                    'Password': '%(ADMIN_PASSWORD)'
                },
                'SqlSvcCreds': {
                    'UserName': SQL_SVC_USERNAME,
                    'Password': '%(SERVICE_ACCOUNT_PASSWORD)'
                },
                'SPSetupCreds': {
                    'UserName': SP_SETUP_SVC_USERNAME,
                    'Password': '%(SERVICE_ACCOUNT_PASSWORD)'
                }
            }
        }
    },
    "sp": {
        'location': LOCATION,
        'force_update_tag': '1.0',
        'publisher': 'Microsoft.Powershell',
        'virtual_machine_extension_type': 'DSC',
        'type_handler_version': '2.9',
        'auto_upgrade_minor_version': True,
        'settings': {
            'wmfVersion': 'latest',
            'configuration': {
                'url': ARTIFACTS_URI + 'dsc/ConfigureSPVM.zip',
                'script': 'ConfigureSPVM.ps1',
                'function': 'ConfigureSPVM'
            },
            'configurationArguments': {
                'DNSServer': VM_REFERENCE["dc"]["nicPrivateIPAddress"],
                'DomainFQDN': DOMAIN_FQDN,
                'DCName': VM_REFERENCE["dc"]["vmName"],
                'SQLName': VM_REFERENCE["sql"]["vmName"],
                'SQLAlias': SQL_ALIAS,
                'SharePointVersion': SHAREPOINT_VERSION
            },
            'privacy': {
                'dataCollection': 'enable'
            }
        },
        'protected_settings': {
            'configurationArguments': {
                'DomainAdminCreds': {
                    'UserName': ADMIN_USERNAME,
                    'Password': '%(ADMIN_PASSWORD)'
                },
                'SPSetupCreds': {
                    'UserName': SP_SETUP_SVC_USERNAME,
                    'Password': '%(SERVICE_ACCOUNT_PASSWORD)'
                },
                'SPFarmCreds': {
                    'UserName': SP_FARM_USERNAME,
                    'Password': '%(SERVICE_ACCOUNT_PASSWORD)'
                },
                'SPSvcCreds': {
                    'UserName': SP_SVC_USERNAME,
                    'Password': '%(SERVICE_ACCOUNT_PASSWORD)'
                },
                'SPAppPoolCreds': {
                    'UserName': SP_APPPOOL_USERNAME,
                    'Password': '%(SERVICE_ACCOUNT_PASSWORD)'
                },
                'SPPassphraseCreds': {
                    'UserName': 'Passphrase',
                    'Password': '%(SERVICE_ACCOUNT_PASSWORD)'
                },
                'SPSuperUserCreds': {
                    'UserName': SP_SUPERUSER_NAME,
                    'Password': '%(SERVICE_ACCOUNT_PASSWORD)'
                },
                'SPSuperReaderCreds': {
                    'UserName': SP_SUPERREADER_NAME,
                    'Password': '%(SERVICE_ACCOUNT_PASSWORD)'
                }
            }
        }
    }
}

def get_credentials():
    # define vars as global, so that function sets the global ones instead of just the local copy
    global PASSWORDS
    global VM_DSC_REFERENCE

    PASSWORDS["ADMIN_PASSWORD"] = os.environ['ADMINPASSWORD']
    PASSWORDS["SERVICE_ACCOUNT_PASSWORD"] = os.environ['ADMINPASSWORD']

    # TODO: Find a better way to set the password in VM_DSC_REFERENCE
    VM_DSC_REFERENCE["dc"]["protected_settings"]["configurationArguments"]["AdminCreds"]["Password"] = PASSWORDS["ADMIN_PASSWORD"]
    VM_DSC_REFERENCE["dc"]["protected_settings"]["configurationArguments"]["AdfsSvcCreds"]["Password"] = PASSWORDS["SERVICE_ACCOUNT_PASSWORD"]
    VM_DSC_REFERENCE["sql"]["protected_settings"]["configurationArguments"]["DomainAdminCreds"]["Password"] = PASSWORDS["ADMIN_PASSWORD"]
    VM_DSC_REFERENCE["sql"]["protected_settings"]["configurationArguments"]["SqlSvcCreds"]["Password"] = PASSWORDS["SERVICE_ACCOUNT_PASSWORD"]
    VM_DSC_REFERENCE["sql"]["protected_settings"]["configurationArguments"]["SPSetupCreds"]["Password"] = PASSWORDS["SERVICE_ACCOUNT_PASSWORD"]
    VM_DSC_REFERENCE["sp"]["protected_settings"]["configurationArguments"]["DomainAdminCreds"]["Password"] = PASSWORDS["ADMIN_PASSWORD"]
    VM_DSC_REFERENCE["sp"]["protected_settings"]["configurationArguments"]["SPSetupCreds"]["Password"] = PASSWORDS["SERVICE_ACCOUNT_PASSWORD"]
    VM_DSC_REFERENCE["sp"]["protected_settings"]["configurationArguments"]["SPFarmCreds"]["Password"] = PASSWORDS["SERVICE_ACCOUNT_PASSWORD"]
    VM_DSC_REFERENCE["sp"]["protected_settings"]["configurationArguments"]["SPSvcCreds"]["Password"] = PASSWORDS["SERVICE_ACCOUNT_PASSWORD"]
    VM_DSC_REFERENCE["sp"]["protected_settings"]["configurationArguments"]["SPAppPoolCreds"]["Password"] = PASSWORDS["SERVICE_ACCOUNT_PASSWORD"]
    VM_DSC_REFERENCE["sp"]["protected_settings"]["configurationArguments"]["SPPassphraseCreds"]["Password"] = PASSWORDS["SERVICE_ACCOUNT_PASSWORD"]
    VM_DSC_REFERENCE["sp"]["protected_settings"]["configurationArguments"]["SPSuperUserCreds"]["Password"] = PASSWORDS["SERVICE_ACCOUNT_PASSWORD"]
    VM_DSC_REFERENCE["sp"]["protected_settings"]["configurationArguments"]["SPSuperReaderCreds"]["Password"] = PASSWORDS["SERVICE_ACCOUNT_PASSWORD"]

    subscription_id = os.environ['AZURE_SUBSCRIPTION_ID']
    credentials = ServicePrincipalCredentials(
        client_id = os.environ['AZURE_CLIENT_ID'],
        secret = os.environ['AZURE_CLIENT_SECRET'],
        tenant = os.environ['AZURE_TENANT_ID']
    )
    return credentials, subscription_id

def create_template():
    credentials, subscription_id = get_credentials()
    resource_client = ResourceManagementClient(credentials, subscription_id)
    compute_client = ComputeManagementClient(credentials, subscription_id)
    network_client = NetworkManagementClient(credentials, subscription_id)

    # Create Resource group
    print(f'Check Resource Group {GROUP_NAME}')
    resource_client.resource_groups.create_or_update(
        GROUP_NAME, {'location': LOCATION})
        
    # Create network security groups
    print('\nCheck network security groups')
    nsgNames = ["NSG-VNet-DC", "NSG-VNet-SQL", "NSG-VNet-SP"]
    for nsgName in nsgNames:
        try:
            nsg_info = network_client.network_security_groups.get(GROUP_NAME, nsgName)
            print(f'\nFound network security group {nsg_info.id}')
        except CloudError:
            print(f'\nCreate network security group {nsgName}')
            nsg_creation = network_client.network_security_groups.create_or_update(GROUP_NAME, nsgName, NSG_PARAMETER)
            nsg_creation.wait()

    """Create network
    """
    # Create VNet
    try:
        vnet_info = network_client.virtual_networks.get(GROUP_NAME, NETWORK_REFERENCE['vNetPrivateName'])
        print(f"\nFound Vnet {vnet_info.name}")
    except CloudError:
        print(f"\nCreate Vnet {NETWORK_REFERENCE['vNetPrivateName']}")
        vnet_creation = network_client.virtual_networks.create_or_update(
            GROUP_NAME,
            NETWORK_REFERENCE['vNetPrivateName'],
            {
                'location': LOCATION,
                'address_space': {
                    'address_prefixes': [NETWORK_REFERENCE['vNetPrivatePrefix']]
                }
            }
        )
        vnet_creation.wait()

    # Create Subnets
    try:
        subnet_dc_info = network_client.subnets.get(GROUP_NAME, NETWORK_REFERENCE['vNetPrivateName'], NETWORK_REFERENCE['vNetPrivateSubnetDCName'])
        print(f'\nFound Subnet {subnet_dc_info.name} for DC')
    except CloudError:
        print('\nCreate Subnet for DC')
        subnet_creation = network_client.subnets.create_or_update(
            GROUP_NAME,
            NETWORK_REFERENCE['vNetPrivateName'],
            NETWORK_REFERENCE['vNetPrivateSubnetDCName'],
            {'address_prefix': NETWORK_REFERENCE['vNetPrivateSubnetDCPrefix']}
        )
        subnet_dc_info = subnet_creation.result()

    try:
        subnet_sql_info = network_client.subnets.get(GROUP_NAME, NETWORK_REFERENCE['vNetPrivateName'], NETWORK_REFERENCE['vNetPrivateSubnetSQLName'])
        print(f'\nFound Subnet {subnet_sql_info.name} for SQL')
    except CloudError:
        print('\nCreate Subnet for SQL')
        subnet_creation = network_client.subnets.create_or_update(
            GROUP_NAME,
            NETWORK_REFERENCE['vNetPrivateName'],
            NETWORK_REFERENCE['vNetPrivateSubnetSQLName'],
            {'address_prefix': NETWORK_REFERENCE['vNetPrivateSubnetSQLPrefix']}
        )
        subnet_sql_info = subnet_creation.result()

    try:
        subnet_sp_info = network_client.subnets.get(GROUP_NAME, NETWORK_REFERENCE['vNetPrivateName'], NETWORK_REFERENCE['vNetPrivateSubnetSPName'])
        print(f'\nFound Subnet {subnet_sp_info.name} for SP')
    except CloudError:
        print(f'\nCreate Subnet for SP')
        subnet_creation = network_client.subnets.create_or_update(
            GROUP_NAME,
            NETWORK_REFERENCE['vNetPrivateName'],
            NETWORK_REFERENCE['vNetPrivateSubnetSPName'],
            {'address_prefix': NETWORK_REFERENCE['vNetPrivateSubnetSPPrefix']}
        )
        subnet_sp_info = subnet_creation.result()

    # Create public IP addresses
    pips_info = []
    for vm in VM_REFERENCE:
        vmJson = str(VM_REFERENCE[vm]).replace("\'", "\"")
        vmDetails = json.loads(vmJson)

        try:
            pip_info = network_client.public_ip_addresses.get(GROUP_NAME, vmDetails['vmPublicIPName'])
            print(f'\nPublic IP address {pip_info.id} already exists')
            pips_info.append(pip_info)
        except CloudError:
            print(f'\nCreate public IP address for {vmDetails["vmName"]}')
            pip_creation = network_client.public_ip_addresses.create_or_update(
                GROUP_NAME,
                vmDetails['vmPublicIPName'],
                {'location': LOCATION, 'public_ip_allocation_method': 'Dynamic', 
                'dns_settings': {'domain_name_label': vmDetails['vmPublicIPDnsName']}, 'sku': {'name': 'Basic'}}
            )
            pips_info.append(pip_creation.result())            

    # Create VM DC
    try:
        vm_dc_info = compute_client.virtual_machines.get(GROUP_NAME, VM_REFERENCE["dc"]["vmName"])
        print(f'\nVM {vm_dc_info.name} already exists')
    except CloudError:
        print('\nCreate VM DC')
        try:
            nic_dc_info = network_client.network_interfaces.get(GROUP_NAME, VM_REFERENCE["dc"]["vmNicName"])
            print(f'\nNIC {nic_dc_info.name} for VM DC already exists')
        except CloudError:
            print('Create NIC for VM DC')
            nic_dc_creation = network_client.network_interfaces.create_or_update(
                GROUP_NAME,
                VM_REFERENCE["dc"]["vmNicName"],
                {
                    'location': LOCATION,
                    'ip_configurations': [{
                        'name': 'ipconfig1',
                        'private_ip_allocation_method': 'Static',
                        'private_ip_address': '10.0.1.4',
                        'subnet': {
                            'id': subnet_dc_info.id
                        },
                        'public_ip_address': pips_info[0]
                    }]
                }
            )
            nic_dc_info = nic_dc_creation.result()

        print('Create virtual machine')
        vm_parameters = create_vm_definition(nic_dc_info.id, VM_REFERENCE['dc'])
        vm_creation = compute_client.virtual_machines.create_or_update(
            GROUP_NAME, DC_NAME, vm_parameters)
        vm_dc_info = vm_creation.result()

    # https://docs.microsoft.com/en-us/python/api/azure-mgmt-compute/azure.mgmt.compute.v2019_07_01.operations.virtualmachineextensionsoperations
    # https://docs.microsoft.com/en-us/python/api/azure-mgmt-compute/azure.mgmt.compute.v2019_07_01.models.virtualmachineextension?view=azure-python
    try:
        vm_dc_dsc_info = compute_client.virtual_machine_extensions.get(GROUP_NAME, vm_dc_info.name, 'ConfigureDCVM')
        print(f'\nDSC configuration for VM {vm_dc_info.name} already exists and is in state {vm_dc_dsc_info.provisioning_state}')
    except CloudError:    
        print(f'\nRun DSC configuration for VM {vm_dc_info.name}')
        compute_client.virtual_machine_extensions.create_or_update(
            GROUP_NAME,
            vm_dc_info.name,
            'ConfigureDCVM',
            VM_DSC_REFERENCE["dc"]
        )
    
    # Create VM SQL
    vm_info = create_vm(compute_client, network_client, VM_REFERENCE["sql"],
        {
            'location': LOCATION,
            'ip_configurations': [{
                'name': 'ipconfig1',
                'private_ip_allocation_method': 'Dynamic',
                'subnet': {
                    'id': subnet_sql_info.id
                },
                'public_ip_address': pips_info[1]
            }]
        })

    # https://docs.microsoft.com/en-us/python/api/azure-mgmt-compute/azure.mgmt.compute.v2019_07_01.operations.virtualmachineextensionsoperations
    # https://docs.microsoft.com/en-us/python/api/azure-mgmt-compute/azure.mgmt.compute.v2019_07_01.models.virtualmachineextension?view=azure-python
    try:
        vm_sql_dsc_info = compute_client.virtual_machine_extensions.get(GROUP_NAME, vm_info.name, 'ConfigureSQLVM')
        print(f'\nDSC configuration for VM {vm_info.name} already exists and is in state {vm_sql_dsc_info.provisioning_state}')
        if vm_sql_dsc_info.provisioning_state != "Succeeded":
            print(f'\nRun DSC configuration for VM {vm_info.name}')
            vm_sql_dsc_creation = compute_client.virtual_machine_extensions.create_or_update(
                GROUP_NAME,
                vm_info.name,
                'ConfigureSQLVM',
                VM_DSC_REFERENCE["sql"]
            )    
    except CloudError:
        print(f'\nRun DSC configuration for VM {vm_info.name}')
        vm_sql_dsc_creation = compute_client.virtual_machine_extensions.create_or_update(
            GROUP_NAME,
            vm_info.name,
            'ConfigureSQLVM',
            VM_DSC_REFERENCE["sql"]
        )
    
    # Create VM SP
    vm_info = create_vm(compute_client, network_client, VM_REFERENCE["sp"],
        {
            'location': LOCATION,
            'ip_configurations': [{
                'name': 'ipconfig1',
                'private_ip_allocation_method': 'Dynamic',
                'subnet': {
                    'id': subnet_sp_info.id
                },
                'public_ip_address': pips_info[2]
            }]
        })

    # https://docs.microsoft.com/en-us/python/api/azure-mgmt-compute/azure.mgmt.compute.v2019_07_01.operations.virtualmachineextensionsoperations
    # https://docs.microsoft.com/en-us/python/api/azure-mgmt-compute/azure.mgmt.compute.v2019_07_01.models.virtualmachineextension?view=azure-python
    try:
        vm_sp_dsc_info = compute_client.virtual_machine_extensions.get(GROUP_NAME, vm_info.name, 'ConfigureSPVM')
        print(f'\nDSC configuration for VM {vm_info.name} already exists and is in state {vm_sp_dsc_info.provisioning_state}')
        if vm_sp_dsc_info.provisioning_state != "Succeeded":
            print(f'\nRun DSC configuration for VM {vm_info.name}')
            vm_sp_dsc_creation = compute_client.virtual_machine_extensions.create_or_update(
                GROUP_NAME,
                vm_info.name,
                'ConfigureSPVM',
                VM_DSC_REFERENCE["sp"]
            )
    except CloudError:
        print(f'\nRun DSC configuration for VM {vm_info.name}')
        vm_sp_dsc_creation = compute_client.virtual_machine_extensions.create_or_update(
            GROUP_NAME,
            vm_info.name,
            'ConfigureSPVM',
            VM_DSC_REFERENCE["sp"]
        )

def create_vm(compute_client, network_client, vm_reference, network_configuration):
    try:
        vm_info = compute_client.virtual_machines.get(GROUP_NAME, vm_reference["vmName"])
        print(f'\nVM {vm_info.name} already exists')
    except CloudError:
        print(f'\nCreate VM {vm_reference["vmName"]}')
        try:
            nic_info = network_client.network_interfaces.get(GROUP_NAME, vm_reference["vmNicName"])
            print(f'\nNIC {nic_info.name} for VM SP already exists')
        except CloudError:
            print(f'Create NIC {vm_reference["vmNicName"]} for VM {vm_reference["vmName"]}')
            nic_creation = network_client.network_interfaces.create_or_update(
                GROUP_NAME,
                vm_reference["vmNicName"],
                network_configuration
            )
            nic_info = nic_creation.result()

        print(f'Create virtual machine {vm_reference["vmName"]}')
        vm_parameters = create_vm_definition(nic_info.id, vm_reference)
        vm_creation = compute_client.virtual_machines.create_or_update(GROUP_NAME, vm_reference["vmName"], vm_parameters)
        vm_info = vm_creation.result()
    return vm_info

def create_vm_definition(nic_id, vm_reference):
    """Create the definition of the VM
    """
    return {
        'location': LOCATION,
        'os_profile': {
            'computer_name': vm_reference['vmName'],
            'admin_username': ADMIN_USERNAME,
            'admin_password': PASSWORDS["ADMIN_PASSWORD"],
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

def replace_in_dict(input, variables):
    result = {}
    for key, value in input.items():
        if isinstance(value, dict):
            result[key] = replace_in_dict(value, variables)
        else:
            result[key] = value % variables
    return result

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

    # print(f'\nTEST {VM_REFERENCE["dc"]["nicPrivateIPAddress"]}')
    # pips_info = []
    # pips_info.append("item1")
    # pips_info.append("item2")
    # pips_info.append("item3")
    # print(f'\nTEST {pips_info[0]}')

    # replace_in_dict(example_dict, variables)
    ADMIN_PASSWORD = os.environ['ADMINPASSWORD']
    SERVICE_ACCOUNT_PASSWORD = ADMIN_PASSWORD
    PASSWORDS["ADMIN_PASSWORD"] = ADMIN_PASSWORD
    PASSWORDS["SERVICE_ACCOUNT_PASSWORD"] = SERVICE_ACCOUNT_PASSWORD
    #result = replace_in_dict(example_dict, PASSWORDS)
    result = replace_in_dict(VM_DSC_REFERENCE, PASSWORDS)
    print(f'\nresult after: {result}')
    

if __name__ == "__main__":
    create_template()
    # tests()
    
    

