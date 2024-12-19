metadata description = 'Deploy SharePoint Subscription / 2019 / 2016 with a lightweight configuration. Each version is independent and may or may not be deployed.'
metadata author = 'Yvand'

@description('Location for all the resources.')
param location string = resourceGroup().location

@description('Specify if a SharePoint Subscription farm should be provisioned, and which version if so.')
@allowed([
  'No'
  'Subscription-RTM'
  'Subscription-22H2'
  'Subscription-23H1'
  'Subscription-23H2'
  'Subscription-Latest'
])
param provisionSharePointSubscription string = 'Subscription-Latest'

@description('Specify if a SharePoint 2019 farm should be provisioned.')
param provisionSharePoint2019 bool = false

@description('Specify if a SharePoint 2016 farm should be provisioned.')
param provisionSharePoint2016 bool = false

@description('FQDN of the AD forest to create.')
@minLength(5)
param domainFQDN string = 'contoso.local'

@description('Specify if ADFS shoulde be provisioned, and used in SharePoint in an extended zone.')
param configureADFS bool = false

@description('Specify if Azure Bastion should be provisioned. See https://azure.microsoft.com/en-us/services/azure-bastion for more information.')
param addAzureBastion bool = false

@description('''
Specify if a rule in the network security groups should allow the inbound RDP traffic:
- "No" (default): No rule is created, RDP traffic is blocked.
- "*" or "Internet": RDP traffic is allowed from everywhere.
- CIDR notation (e.g. 192.168.99.0/24 or 2001:1234::/64) or an IP address (e.g. 192.168.99.0 or 2001:1234::): RDP traffic is allowed from the IP address / pattern specified.
''')
@minLength(1)
param rdpTrafficRule string = 'No'

@description('Name of the AD and SharePoint administrator. \'admin\' and \'administrator\' are not allowed.')
@minLength(1)
param adminUsername string

@description('Input must meet password complexity requirements as documented in https://learn.microsoft.com/azure/virtual-machines/windows/faq#what-are-the-password-requirements-when-creating-a-vm-')
@minLength(8)
@secure()
param adminPassword string

@description('Password for all service accounts and SharePoint passphrase. Input must meet password complexity requirements as documented in https://learn.microsoft.com/azure/virtual-machines/windows/faq#what-are-the-password-requirements-when-creating-a-vm-')
@minLength(8)
@secure()
param serviceAccountsPassword string

@description('Time zone of the virtual machines. Type "[TimeZoneInfo]::GetSystemTimeZones().Id" in PowerShell to get the list.')
@minLength(2)
@allowed([
  'Dateline Standard Time'
  'UTC-11'
  'Aleutian Standard Time'
  'Hawaiian Standard Time'
  'Marquesas Standard Time'
  'Alaskan Standard Time'
  'UTC-09'
  'Pacific Standard Time (Mexico)'
  'UTC-08'
  'Pacific Standard Time'
  'US Mountain Standard Time'
  'Mountain Standard Time (Mexico)'
  'Mountain Standard Time'
  'Central America Standard Time'
  'Central Standard Time'
  'Easter Island Standard Time'
  'Central Standard Time (Mexico)'
  'Canada Central Standard Time'
  'SA Pacific Standard Time'
  'Eastern Standard Time (Mexico)'
  'Eastern Standard Time'
  'Haiti Standard Time'
  'Cuba Standard Time'
  'US Eastern Standard Time'
  'Turks And Caicos Standard Time'
  'Paraguay Standard Time'
  'Atlantic Standard Time'
  'Venezuela Standard Time'
  'Central Brazilian Standard Time'
  'SA Western Standard Time'
  'Pacific SA Standard Time'
  'Newfoundland Standard Time'
  'Tocantins Standard Time'
  'E. South America Standard Time'
  'SA Eastern Standard Time'
  'Argentina Standard Time'
  'Greenland Standard Time'
  'Montevideo Standard Time'
  'Magallanes Standard Time'
  'Saint Pierre Standard Time'
  'Bahia Standard Time'
  'UTC-02'
  'Mid-Atlantic Standard Time'
  'Azores Standard Time'
  'Cape Verde Standard Time'
  'UTC'
  'GMT Standard Time'
  'Greenwich Standard Time'
  'Sao Tome Standard Time'
  'Morocco Standard Time'
  'W. Europe Standard Time'
  'Central Europe Standard Time'
  'Romance Standard Time'
  'Central European Standard Time'
  'W. Central Africa Standard Time'
  'Jordan Standard Time'
  'GTB Standard Time'
  'Middle East Standard Time'
  'Egypt Standard Time'
  'E. Europe Standard Time'
  'Syria Standard Time'
  'West Bank Standard Time'
  'South Africa Standard Time'
  'FLE Standard Time'
  'Israel Standard Time'
  'Kaliningrad Standard Time'
  'Sudan Standard Time'
  'Libya Standard Time'
  'Namibia Standard Time'
  'Arabic Standard Time'
  'Turkey Standard Time'
  'Arab Standard Time'
  'Belarus Standard Time'
  'Russian Standard Time'
  'E. Africa Standard Time'
  'Iran Standard Time'
  'Arabian Standard Time'
  'Astrakhan Standard Time'
  'Azerbaijan Standard Time'
  'Russia Time Zone 3'
  'Mauritius Standard Time'
  'Saratov Standard Time'
  'Georgian Standard Time'
  'Volgograd Standard Time'
  'Caucasus Standard Time'
  'Afghanistan Standard Time'
  'West Asia Standard Time'
  'Ekaterinburg Standard Time'
  'Pakistan Standard Time'
  'Qyzylorda Standard Time'
  'India Standard Time'
  'Sri Lanka Standard Time'
  'Nepal Standard Time'
  'Central Asia Standard Time'
  'Bangladesh Standard Time'
  'Omsk Standard Time'
  'Myanmar Standard Time'
  'SE Asia Standard Time'
  'Altai Standard Time'
  'W. Mongolia Standard Time'
  'North Asia Standard Time'
  'N. Central Asia Standard Time'
  'Tomsk Standard Time'
  'China Standard Time'
  'North Asia East Standard Time'
  'Singapore Standard Time'
  'W. Australia Standard Time'
  'Taipei Standard Time'
  'Ulaanbaatar Standard Time'
  'Aus Central W. Standard Time'
  'Transbaikal Standard Time'
  'Tokyo Standard Time'
  'North Korea Standard Time'
  'Korea Standard Time'
  'Yakutsk Standard Time'
  'Cen. Australia Standard Time'
  'AUS Central Standard Time'
  'E. Australia Standard Time'
  'AUS Eastern Standard Time'
  'West Pacific Standard Time'
  'Tasmania Standard Time'
  'Vladivostok Standard Time'
  'Lord Howe Standard Time'
  'Bougainville Standard Time'
  'Russia Time Zone 10'
  'Magadan Standard Time'
  'Norfolk Standard Time'
  'Sakhalin Standard Time'
  'Central Pacific Standard Time'
  'Russia Time Zone 11'
  'New Zealand Standard Time'
  'UTC+12'
  'Fiji Standard Time'
  'Kamchatka Standard Time'
  'Chatham Islands Standard Time'
  'UTC+13'
  'Tonga Standard Time'
  'Samoa Standard Time'
  'Line Islands Standard Time'
])
param timeZone string = 'Romance Standard Time'

@description('Enable automatic Windows Updates.')
param enableAutomaticUpdates bool = true

@description('Enable Azure Hybrid Benefit to use your on-premises Windows Server licenses and reduce cost. See https://docs.microsoft.com/en-us/azure/virtual-machines/windows/hybrid-use-benefit-licensing for more information.')
param enableHybridBenefitServerLicenses bool = false

@description('Size of the DC VM')
param vmDcSize string = 'Standard_B2als_v2'

@description('Type of storage for the managed disks. Visit \'https://docs.microsoft.com/en-us/rest/api/compute/disks/list#diskstorageaccounttypes\' for more information')
@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'StandardSSD_ZRS'
  'Premium_LRS'
  'PremiumV2_LRS'
  'Premium_ZRS'
  'UltraSSD_LRS'
])
param vmDcStorage string = 'StandardSSD_LRS'

@description('Size of the SQL VM')
param vmSqlSize string = 'Standard_B2as_v2'

@description('Type of storage for the managed disks. Visit \'https://docs.microsoft.com/en-us/rest/api/compute/disks/list#diskstorageaccounttypes\' for more information')
@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'StandardSSD_ZRS'
  'Premium_LRS'
  'PremiumV2_LRS'
  'Premium_ZRS'
  'UltraSSD_LRS'
])
param vmSqlStorage string = 'StandardSSD_LRS'

@description('Size of the SharePoint VM')
param vmSharePointSize string = 'Standard_B4as_v2'

@description('Type of storage for the managed disks. Visit \'https://docs.microsoft.com/en-us/rest/api/compute/disks/list#diskstorageaccounttypes\' for more information')
@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'StandardSSD_ZRS'
  'Premium_LRS'
  'PremiumV2_LRS'
  'Premium_ZRS'
  'UltraSSD_LRS'
])
param vmSharePointStorage string = 'StandardSSD_LRS'

@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param _artifactsLocation string = 'https://github.com/Yvand/AzureRM-Templates/raw/master/Templates/DTL-SharePoint-AllVersions-light'

@description('The sasToken required to access _artifactsLocation. When the template is deployed using the accompanying scripts, a sasToken will be automatically generated.')
@secure()
param _artifactsLocationSasToken string = ''

// Local variables
var resourceGroupNameFormatted = replace(
  replace(replace(replace(resourceGroup().name, '.', '-'), '(', '-'), ')', '-'),
  '_',
  '-'
)
var _artifactsLocationWithTrailingSlash = '${_artifactsLocation}/'
var sharePointSettings = {
  sharePointImagesList: {
    Subscription: 'MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition-smalldisk:latest'
    sp2019: 'MicrosoftSharePoint:MicrosoftSharePointServer:sp2019gen2smalldisk:latest'
    sp2016: 'MicrosoftSharePoint:MicrosoftSharePointServer:sp2016:latest'
  }
  sharePointSubscriptionBits: [
    {
      Label: 'RTM'
      Packages: [
        {
          DownloadUrl: 'https://download.microsoft.com/download/3/f/5/3f5f8a7e-462b-41ff-a5b2-04bdf5821ceb/OfficeServer.iso'
          ChecksumType: 'SHA256'
          Checksum: 'C576B847C573234B68FC602A0318F5794D7A61D8149EB6AE537AF04470B7FC05'
        }
      ]
    }
    {
      Label: '22H2'
      Packages: [
        {
          DownloadUrl: 'https://download.microsoft.com/download/8/d/f/8dfcb515-6e49-42e5-b20f-5ebdfd19d8e7/wssloc-subscription-kb5002270-fullfile-x64-glb.exe'
          ChecksumType: 'SHA256'
          Checksum: '7E496530EB873146650A9E0653DE835CB2CAD9AF8D154CBD7387BB0F2297C9FC'
        }
        {
          DownloadUrl: 'https://download.microsoft.com/download/3/f/5/3f5b1ee0-3336-45d7-b2f4-1e6af977d574/sts-subscription-kb5002271-fullfile-x64-glb.exe'
          ChecksumType: 'SHA256'
          Checksum: '247011443AC573D4F03B1622065A7350B8B3DAE04D6A5A6DC64C8270A3BE7636'
        }
      ]
    }
    {
      Label: '23H1'
      Packages: [
        {
          DownloadUrl: 'https://download.microsoft.com/download/c/6/a/c6a17105-3d86-42ad-888d-49b22383bfa1/uber-subscription-kb5002355-fullfile-x64-glb.exe'
        }
      ]
    }
    {
      Label: '23H2'
      Packages: [
        {
          DownloadUrl: 'https://download.microsoft.com/download/f/5/5/f5559e3f-8b24-419f-b238-b09cf986e927/uber-subscription-kb5002474-fullfile-x64-glb.exe'
        }
      ]
    }
    {
      Label: 'Latest'
      Packages: [
        {
          DownloadUrl: 'https://download.microsoft.com/download/c/e/c/ceca0241-efca-4484-9d76-5661806f16c4/uber-subscription-kb5002658-fullfile-x64-glb.exe'
        }
      ]
    }
  ]
}
var networkSettings = {
  vNetPrivatePrefix: '10.1.0.0/16'
  subnetDCPrefix: '10.1.1.0/24'
  dcPrivateIPAddress: '10.1.1.4'
  subnetSQLPrefix: '10.1.2.0/24'
  subnetSPPrefix: '10.1.3.0/24'
  vNetPrivateName: '${resourceGroupNameFormatted}-vnet'
  subnetDCName: 'Subnet-DC'
  subnetSQLName: 'Subnet-SQL'
  subnetSPName: 'Subnet-SP'
  nsgSubnetDCName: 'NSG-Subnet-DC'
  nsgSubnetSQLName: 'NSG-Subnet-SQL'
  nsgSubnetSPName: 'NSG-Subnet-SP'
  nsgRuleAllowIncomingRdp: [
    {
      name: 'allow-rdp-rule'
      properties: {
        description: 'Allow RDP'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '3389'
        sourceAddressPrefix: rdpTrafficRule
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 110
        direction: 'Inbound'
      }
    }
  ]
}
var vmsSettings = {
  enableAutomaticUpdates: true
  vmDCName: 'DC'
  vmSQLName: 'SQL'
  vmSPSubscriptionName: 'SPSE'
  vmSP2019Name: 'SP2019'
  vmSP2016Name: 'SP2016'
  vmDCImage: 'MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition-smalldisk:latest'
  vmSQLImage: 'MicrosoftSQLServer:sql2022-ws2022:sqldev-gen2:latest'
  vmSPSubscriptionImage: sharePointSettings.sharePointImagesList.Subscription
  vmSP2019Image: sharePointSettings.sharePointImagesList.sp2019
  vmSP2016Image: sharePointSettings.sharePointImagesList.sp2016
}
var vmsResourcesNames = {
  vmDCNicName: 'NIC-${vmsSettings.vmDCName}-0'
  vmDCPublicIPName: 'PublicIP-${vmsSettings.vmDCName}'
  vmSQLNicName: 'NIC-${vmsSettings.vmSQLName}-0'
  vmSQLPublicIPName: 'PublicIP-${vmsSettings.vmSQLName}'
  vmSPSubscriptionNicName: 'NIC-${vmsSettings.vmSPSubscriptionName}-0'
  vmSPSubscriptionPublicIPName: 'PublicIP-${vmsSettings.vmSPSubscriptionName}'
  vmSP2019NicName: 'NIC-${vmsSettings.vmSP2019Name}-0'
  vmSP2019PublicIPName: 'PublicIP-${vmsSettings.vmSP2019Name}'
  vmSP2016NicName: 'NIC-${vmsSettings.vmSP2016Name}-0'
  vmSP2016PublicIPName: 'PublicIP-${vmsSettings.vmSP2016Name}'
}
var dscSettings = {
  forceUpdateTag: '1.0'
  vmDCScriptFileUri: uri(_artifactsLocationWithTrailingSlash, 'dsc/ConfigureDCVM.zip${_artifactsLocationSasToken}')
  vmDCScript: 'ConfigureDCVM.ps1'
  vmDCFunction: 'ConfigureDCVM'
  vmSQLScriptFileUri: uri(_artifactsLocationWithTrailingSlash, 'dsc/ConfigureSQLVM.zip${_artifactsLocationSasToken}')
  vmSQLScript: 'ConfigureSQLVM.ps1'
  vmSQLFunction: 'ConfigureSQLVM'
  vmSPSubscriptionScriptFileUri: uri(
    _artifactsLocationWithTrailingSlash,
    'dsc/ConfigureSPSE.zip${_artifactsLocationSasToken}'
  )
  vmSPLegacyScriptFileUri: uri(
    _artifactsLocationWithTrailingSlash,
    'dsc/ConfigureSPLegacy.zip${_artifactsLocationSasToken}'
  )
  vmSPSubscriptionScript: 'ConfigureSPSE.ps1'
  vmSPLegacyScript: 'ConfigureSPLegacy.ps1'
  vmSPFunction: 'ConfigureSPVM'
}
var deploymentSettings = {
  sharePointSitesAuthority: 'spsites'
  sharePointCentralAdminPort: 5000
  localAdminUserName: 'l-${uniqueString(subscription().subscriptionId)}'
  enableAnalysis: false
  applyBrowserPolicies: true
  sqlAlias: 'SQLAlias'
  spSuperUserName: 'spSuperUser'
  spSuperReaderName: 'spSuperReader'
  adfsSvcUserName: 'adfssvc'
  sqlSvcUserName: 'sqlsvc'
  spSetupUserName: 'spsetup'
  spFarmUserName: 'spfarm'
  spSvcUserName: 'spsvc'
  spAppPoolUserName: 'spapppool'
  spADDirSyncUserName: 'spdirsync'
}

// Start creating resources
// Network security groups for each subnet
resource nsg_subnet_dc 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'vnet-subnet-dc-nsg'
  location: location
  properties: {
    securityRules: ((toLower(rdpTrafficRule) == 'no') ? null : networkSettings.nsgRuleAllowIncomingRdp)
  }
}

resource nsg_subnet_sql 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'vnet-subnet-sql-nsg'
  location: location
  properties: {
    securityRules: ((toLower(rdpTrafficRule) == 'no') ? null : networkSettings.nsgRuleAllowIncomingRdp)
  }
}

resource nsg_subnet_sp 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'vnet-subnet-sp-nsg'
  location: location
  properties: {
    securityRules: ((toLower(rdpTrafficRule) == 'no') ? null : networkSettings.nsgRuleAllowIncomingRdp)
  }
}

// Create the virtual network, 3 subnets, and associate each subnet with its Network Security Group
resource virtual_network 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'vnet-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkSettings.vNetPrivatePrefix
      ]
    }
    subnets: [
      {
        name: networkSettings.subnetDCName
        properties: {
          defaultOutboundAccess: false
          addressPrefix: networkSettings.subnetDCPrefix
          networkSecurityGroup: {
            id: nsg_subnet_dc.id
          }
        }
      }
      {
        name: networkSettings.subnetSQLName
        properties: {
          defaultOutboundAccess: false
          addressPrefix: networkSettings.subnetSQLPrefix
          networkSecurityGroup: {
            id: nsg_subnet_sql.id
          }
        }
      }
      {
        name: networkSettings.subnetSPName
        properties: {
          defaultOutboundAccess: false
          addressPrefix: networkSettings.subnetSPPrefix
          networkSecurityGroup: {
            id: nsg_subnet_sp.id
          }
        }
      }
    ]
  }
}

// Create resources for VM DC
resource vm_dc_pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'vm-dc-pip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${resourceGroupNameFormatted}-${vmsSettings.vmDCName}')
    }
  }
}

resource vm_dc_nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'vm-dc-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: networkSettings.dcPrivateIPAddress
          subnet: {
            id: resourceId(
              'Microsoft.Network/virtualNetworks/subnets',
              virtual_network.name,
              networkSettings.subnetDCName
            )
          }
          publicIPAddress: { id: vm_dc_pip.id }
        }
      }
    ]
  }
}

resource vm_dc_def 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-dc'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmDcSize
    }
    osProfile: {
      computerName: vmsSettings.vmDCName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        timeZone: timeZone
        enableAutomaticUpdates: vmsSettings.enableAutomaticUpdates
        provisionVMAgent: true
        patchSettings: {
          patchMode: (vmsSettings.enableAutomaticUpdates ? 'AutomaticByOS' : 'Manual')
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: split(vmsSettings.vmDCImage, ':')[0]
        offer: split(vmsSettings.vmDCImage, ':')[1]
        sku: split(vmsSettings.vmDCImage, ':')[2]
        version: split(vmsSettings.vmDCImage, ':')[3]
      }
      osDisk: {
        name: 'vm-dc-disk-os'
        caching: 'ReadWrite'
        osType: 'Windows'
        createOption: 'FromImage'
        diskSizeGB: 32
        managedDisk: {
          storageAccountType: vmDcStorage
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm_dc_nic.id
        }
      ]
    }
    licenseType: (enableHybridBenefitServerLicenses ? 'Windows_Server' : null)
  }
}
