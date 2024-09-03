metadata description = 'Create a SharePoint Subscription / 2019 / 2016 farm with an extensive configuration that would take ages to perform manually, and install useful softwares like Fiddler, vscode, np++, 7zip, ULS Viewer to get ready to use'
metadata author = 'Yvand'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Version of SharePoint farm to create.')
@allowed([
  'Subscription-Latest'
  'Subscription-23H2'
  'Subscription-23H1'
  'Subscription-22H2'
  'Subscription-RTM'
  '2019'
  '2016'
])
param sharePointVersion string = 'Subscription-Latest'

@description('FQDN of the AD forest to create.')
@minLength(5)
param domainFQDN string = 'contoso.local'

@description('Number of MinRole Front-end to add to the farm. The MinRole type can be changed later as needed.')
@allowed([
  0
  1
  2
  3
  4
])
param numberOfAdditionalFrontEnd int = 0

@description('Specify if Azure Bastion should be provisioned. See https://azure.microsoft.com/en-us/services/azure-bastion for more information.')
param addAzureBastion bool = false

@description('''
Select how the virtual machines connect to internet.
IMPORTANT: With AzureFirewallProxy, you need to either enable Azure Bastion, or manually add a public IP address to a virtual machine, to be able to connect to it.
''')
@allowed([
  'PublicIPAddress'
  'AzureFirewallProxy'
])
param outbound_access_method string = 'PublicIPAddress'

@description('''
Specify if RDP traffic to the virtual machines is allowed:
- If "No" (default): RDP traffic is blocked.
- If "*" or "Internet": RDP traffic is opened to the world.
- If CIDR notation (e.g. 192.168.99.0/24 or 2001:1234::/64) or an IP address (e.g. 192.168.99.0 or 2001:1234::): RDP traffic is possible for the IP addresses / pattern specified.
''')
@minLength(1)
param RDPTrafficAllowed string = 'No'

@description('Name of the AD and SharePoint administrator. "admin" and "administrator" are not allowed.')
@minLength(1)
param adminUserName string

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
param vmsTimeZone string = 'Romance Standard Time'

@description('The time at which VMs will be automatically shutdown (24h HHmm format). Set value to \'9999\' to NOT configure the auto shutdown.')
@minLength(4)
@maxLength(4)
param vmsAutoShutdownTime string = '1900'

// @description('Enable automatic Windows Updates.')
// param enableAutomaticUpdates bool = true

@description('Enable Azure Hybrid Benefit to use your on-premises Windows Server licenses and reduce cost. See https://docs.microsoft.com/en-us/azure/virtual-machines/windows/hybrid-use-benefit-licensing for more information.')
param enableHybridBenefitServerLicenses bool = false

// @description('Size in Gb of the additional data disk attached to SharePoint VMs. Set to 0 to not create it')
// param sharePointDataDiskSize int = 0

@description('Size of the DC VM')
param vmDCSize string = 'Standard_B2s'

@description('Type of storage for the managed disks. Visit \'https://docs.microsoft.com/en-us/rest/api/compute/disks/list#diskstorageaccounttypes\' for more information')
@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
  'Premium_ZRS'
  'StandardSSD_ZRS'
  'UltraSSD_LRS'
])
param vmDCStorageAccountType string = 'StandardSSD_LRS'

@description('Size of the SQL VM')
param vmSQLSize string = 'Standard_B2ms'

@description('Type of storage for the managed disks. Visit \'https://docs.microsoft.com/en-us/rest/api/compute/disks/list#diskstorageaccounttypes\' for more information')
@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
  'Premium_ZRS'
  'StandardSSD_ZRS'
  'UltraSSD_LRS'
])
param vmSQLStorageAccountType string = 'StandardSSD_LRS'

@description('Size of the SharePoint VM')
param vmSPSize string = 'Standard_B4ms'

@description('Type of storage for the managed disks. Visit \'https://docs.microsoft.com/en-us/rest/api/compute/disks/list#diskstorageaccounttypes\' for more information')
@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
  'Premium_ZRS'
  'StandardSSD_ZRS'
  'UltraSSD_LRS'
])
param vmSPStorageAccountType string = 'StandardSSD_LRS'

@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param _artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation. When the template is deployed using the accompanying scripts, a sasToken will be automatically generated.')
@secure()
param _artifactsLocationSasToken string = ''

var resourceGroupNameFormatted = replace(
  replace(replace(replace(resourceGroup().name, '.', '-'), '(', '-'), ')', '-'),
  '_',
  '-'
)
var sharePointSettings = {
  isSharePointSubscription: (startsWith(sharePointVersion, 'subscription') ? true : false)
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
          DownloadUrl: 'https://download.microsoft.com/download/8/7/9/8798c828-1d2c-442d-9a98-e6ce59166690/uber-subscription-kb5002560-fullfile-x64-glb.exe'
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
  subnetDCName: 'vnet-subnet-dc'
  subnetSQLName: 'vnet-subnet-sql'
  subnetSPName: 'vnet-subnet-sp'
  nsgRuleAllowIncomingRdp: [
    {
      name: 'nsg-rule-allow-rdp'
      properties: {
        description: 'Allow RDP'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '3389'
        sourceAddressPrefix: RDPTrafficAllowed
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
  vmSPName: 'SP'
  vmFEName: 'FE'
  vmDCImage: 'MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition-smalldisk:latest'
  vmSQLImage: 'MicrosoftSQLServer:sql2022-ws2022:sqldev-gen2:latest'
  vmSharePointImage: (sharePointSettings.isSharePointSubscription
    ? sharePointSettings.sharePointImagesList.Subscription
    : ((sharePointVersion == '2019')
        ? sharePointSettings.sharePointImagesList.sp2019
        : sharePointSettings.sharePointImagesList.sp2016))
}
var vmsResourcesNames = {
  vmDCNicName: 'NIC-${vmsSettings.vmDCName}-0'
  vmDCPublicIPName: 'PublicIP-${vmsSettings.vmDCName}'
  vmSQLNicName: 'NIC-${vmsSettings.vmSQLName}-0'
  vmSQLPublicIPName: 'PublicIP-${vmsSettings.vmSQLName}'
  vmSPNicName: 'NIC-${vmsSettings.vmSPName}-0'
  vmSPPublicIPName: 'PublicIP-${vmsSettings.vmSPName}'
  vmFENicName: 'NIC-${vmsSettings.vmFEName}-0'
  vmFEPublicIPName: 'PublicIP-${vmsSettings.vmFEName}'
}
var dscSettings = {
  forceUpdateTag: '1.0'
  vmDCScriptFileUri: uri(_artifactsLocation, 'dsc/ConfigureDCVM.zip${_artifactsLocationSasToken}')
  vmDCScript: 'ConfigureDCVM.ps1'
  vmDCFunction: 'ConfigureDCVM'
  vmSQLScriptFileUri: uri(_artifactsLocation, 'dsc/ConfigureSQLVM.zip${_artifactsLocationSasToken}')
  vmSQLScript: 'ConfigureSQLVM.ps1'
  vmSQLFunction: 'ConfigureSQLVM'
  vmSPScriptFileUri: uri(
    _artifactsLocation,
    '${(sharePointSettings.isSharePointSubscription ? 'dsc/ConfigureSPSE.zip' : 'dsc/ConfigureSPLegacy.zip')}${_artifactsLocationSasToken}'
  )
  vmSPScript: (sharePointSettings.isSharePointSubscription ? 'ConfigureSPSE.ps1' : 'ConfigureSPLegacy.ps1')
  vmSPFunction: 'ConfigureSPVM'
  vmFEScriptFileUri: uri(
    _artifactsLocation,
    '${(sharePointSettings.isSharePointSubscription ? 'dsc/ConfigureFESE.zip' : 'dsc/ConfigureFELegacy.zip')}${_artifactsLocationSasToken}'
  )
  vmFEScript: (sharePointSettings.isSharePointSubscription ? 'ConfigureFESE.ps1' : 'ConfigureFELegacy.ps1')
  vmFEFunction: 'ConfigureFEVM'
}
var deploymentSettings = {
  sharePointSitesAuthority: 'spsites'
  sharePointCentralAdminPort: 5000
  sharePointBitsSelected: (sharePointSettings.isSharePointSubscription
    ? sharePointSettings.sharePointSubscriptionBits
    : 'fake')
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

var firewall_proxy_settings = {
  vNetAzureFirewallPrefix: '10.1.5.0/24'
  azureFirewallIPAddress: '10.1.5.4'
  http_port: '8080'
  https_port: '8443'
}

// Start creating resources
// Network security groups for each subnet
resource nsg_subnet_dc 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'vnet-subnet-dc-nsg'
  location: location
  properties: {
    securityRules: ((toLower(RDPTrafficAllowed) == 'no') ? null : networkSettings.nsgRuleAllowIncomingRdp)
  }
}

resource nsg_subnet_sql 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'vnet-subnet-sql-nsg'
  location: location
  properties: {
    securityRules: ((toLower(RDPTrafficAllowed) == 'no') ? null : networkSettings.nsgRuleAllowIncomingRdp)
  }
}

resource nsg_subnet_sp 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'vnet-subnet-sp-nsg'
  location: location
  properties: {
    securityRules: ((toLower(RDPTrafficAllowed) == 'no') ? null : networkSettings.nsgRuleAllowIncomingRdp)
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
resource vm_dc_pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (outbound_access_method == 'PublicIPAddress') {
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
          publicIPAddress: ((outbound_access_method == 'PublicIPAddress') ? { id: vm_dc_pip.id } : null)
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
      vmSize: vmDCSize
    }
    osProfile: {
      computerName: vmsSettings.vmDCName
      adminUsername: adminUserName
      adminPassword: adminPassword
      windowsConfiguration: {
        timeZone: vmsTimeZone
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
          storageAccountType: vmDCStorageAccountType
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

resource vm_dc_runcommand_setproxy 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = if (outbound_access_method == 'AzureFirewallProxy') {
  parent: vm_dc_def
  name: 'runcommand-setproxy'
  location: location
  properties: {
    source: {
      script: 'param([string]$proxyIp, [string]$proxyHttpPort, [string]$proxyHttpsPort, [string]$localDomainFqdn) $proxy : "http={0}:{1};https={0}:{2}" -f $proxyIp, $proxyHttpPort, $proxyHttpsPort; $bypasslist : "*.{0};<local>" -f $localDomainFqdn; netsh winhttp set proxy proxy-server=$proxy bypass-list=$bypasslist; $proxyEnabled = 1; New-ItemProperty -Path "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" -Name "ProxySettingsPerUser" -PropertyType DWORD -Value 0 -Force; $proxyBytes = [system.Text.Encoding]::ASCII.GetBytes($proxy); $bypassBytes = [system.Text.Encoding]::ASCII.GetBytes($bypasslist); $defaultConnectionSettings = [byte[]]@(@(70, 0, 0, 0, 0, 0, 0, 0, $proxyEnabled, 0, 0, 0, $proxyBytes.Length, 0, 0, 0) + $proxyBytes + @($bypassBytes.Length, 0, 0, 0) + $bypassBytes + @(1..36 | % { 0 })); $registryPaths = @("HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings", "HKLM:\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Internet Settings"); foreach ($registryPath in $registryPaths) { Set-ItemProperty -Path $registryPath -Name ProxyServer -Value $proxy; Set-ItemProperty -Path $registryPath -Name ProxyEnable -Value $proxyEnabled; Set-ItemProperty -Path $registryPath -Name ProxyOverride -Value $bypasslist; Set-ItemProperty -Path "$registryPath\\Connections" -Name DefaultConnectionSettings -Value $defaultConnectionSettings; } Bitsadmin /util /setieproxy localsystem MANUAL_PROXY $proxy $bypasslist;'
    }
    parameters: [
      {
        name: 'proxyIp'
        value: firewall_proxy_settings.azureFirewallIPAddress
      }
      {
        name: 'proxyHttpPort'
        value: firewall_proxy_settings.http_port
      }
      {
        name: 'proxyHttpsPort'
        value: firewall_proxy_settings.https_port
      }
      {
        name: 'proxyIp'
        value: domainFQDN
      }
    ]
    timeoutInSeconds: 90
    treatFailureAsDeploymentFailure: false
  }
}

resource vm_dc_ext_applydsc 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm_dc_def
  name: 'apply-dsc'
  location: location
  dependsOn: [
    vm_dc_runcommand_setproxy
  ]
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.9'
    autoUpgradeMinorVersion: true
    forceUpdateTag: dscSettings.forceUpdateTag
    settings: {
      wmfVersion: 'latest'
      configuration: {
        url: dscSettings.vmDCScriptFileUri
        script: dscSettings.vmDCScript
        function: dscSettings.vmDCFunction
      }
      configurationArguments: {
        domainFQDN: domainFQDN
        PrivateIP: networkSettings.dcPrivateIPAddress
        SPServerName: vmsSettings.vmSPName
        SharePointSitesAuthority: deploymentSettings.sharePointSitesAuthority
        SharePointCentralAdminPort: deploymentSettings.sharePointCentralAdminPort
        ApplyBrowserPolicies: deploymentSettings.applyBrowserPolicies
      }
      privacy: {
        dataCollection: 'enable'
      }
    }
    protectedSettings: {
      configurationArguments: {
        AdminCreds: {
          UserName: adminUserName
          Password: adminPassword
        }
        AdfsSvcCreds: {
          UserName: deploymentSettings.adfsSvcUserName
          Password: serviceAccountsPassword
        }
      }
    }
  }
}

// Create resources for VM SQL
resource vm_sql_pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (outbound_access_method == 'PublicIPAddress') {
  name: 'vm-sql-pip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${resourceGroupNameFormatted}-${vmsSettings.vmSQLName}')
    }
  }
}

resource vm_sql_nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'vm-sql-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId(
              'Microsoft.Network/virtualNetworks/subnets',
              virtual_network.name,
              networkSettings.subnetSQLName
            )
          }
          publicIPAddress: ((outbound_access_method == 'PublicIPAddress') ? { id: vm_sql_pip.id } : null)
        }
      }
    ]
  }
}

resource vm_sql_def 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-sql'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSQLSize
    }
    osProfile: {
      computerName: vmsSettings.vmSQLName
      adminUsername: deploymentSettings.localAdminUserName
      adminPassword: adminPassword
      windowsConfiguration: {
        timeZone: vmsTimeZone
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
        publisher: split(vmsSettings.vmSQLImage, ':')[0]
        offer: split(vmsSettings.vmSQLImage, ':')[1]
        sku: split(vmsSettings.vmSQLImage, ':')[2]
        version: split(vmsSettings.vmSQLImage, ':')[3]
      }
      osDisk: {
        name: 'vm-sql-disk-os'
        caching: 'ReadWrite'
        osType: 'Windows'
        createOption: 'FromImage'
        diskSizeGB: 128
        managedDisk: {
          storageAccountType: vmSQLStorageAccountType
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm_sql_nic.id
        }
      ]
    }
    licenseType: (enableHybridBenefitServerLicenses ? 'Windows_Server' : null)
  }
}

resource vm_sql_runcommand_setproxy 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = if (outbound_access_method == 'AzureFirewallProxy') {
  parent: vm_sql_def
  name: 'runcommand-setproxy'
  location: location
  properties: {
    source: {
      script: 'param([string]$proxyIp, [string]$proxyHttpPort, [string]$proxyHttpsPort, [string]$localDomainFqdn) $proxy : "http={0}:{1};https={0}:{2}" -f $proxyIp, $proxyHttpPort, $proxyHttpsPort; $bypasslist : "*.{0};<local>" -f $localDomainFqdn; netsh winhttp set proxy proxy-server=$proxy bypass-list=$bypasslist; $proxyEnabled = 1; New-ItemProperty -Path "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" -Name "ProxySettingsPerUser" -PropertyType DWORD -Value 0 -Force; $proxyBytes = [system.Text.Encoding]::ASCII.GetBytes($proxy); $bypassBytes = [system.Text.Encoding]::ASCII.GetBytes($bypasslist); $defaultConnectionSettings = [byte[]]@(@(70, 0, 0, 0, 0, 0, 0, 0, $proxyEnabled, 0, 0, 0, $proxyBytes.Length, 0, 0, 0) + $proxyBytes + @($bypassBytes.Length, 0, 0, 0) + $bypassBytes + @(1..36 | % { 0 })); $registryPaths = @("HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings", "HKLM:\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Internet Settings"); foreach ($registryPath in $registryPaths) { Set-ItemProperty -Path $registryPath -Name ProxyServer -Value $proxy; Set-ItemProperty -Path $registryPath -Name ProxyEnable -Value $proxyEnabled; Set-ItemProperty -Path $registryPath -Name ProxyOverride -Value $bypasslist; Set-ItemProperty -Path "$registryPath\\Connections" -Name DefaultConnectionSettings -Value $defaultConnectionSettings; } Bitsadmin /util /setieproxy localsystem MANUAL_PROXY $proxy $bypasslist;'
    }
    parameters: [
      {
        name: 'proxyIp'
        value: firewall_proxy_settings.azureFirewallIPAddress
      }
      {
        name: 'proxyHttpPort'
        value: firewall_proxy_settings.http_port
      }
      {
        name: 'proxyHttpsPort'
        value: firewall_proxy_settings.https_port
      }
      {
        name: 'proxyIp'
        value: domainFQDN
      }
    ]
    timeoutInSeconds: 90
    treatFailureAsDeploymentFailure: false
  }
}

resource vm_sql_ext_applydsc 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm_sql_def
  name: 'apply-dsc'
  location: location
  dependsOn: [
    vm_sql_runcommand_setproxy
  ]
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.9'
    autoUpgradeMinorVersion: true
    forceUpdateTag: dscSettings.forceUpdateTag
    settings: {
      wmfVersion: 'latest'
      configuration: {
        url: dscSettings.vmSQLScriptFileUri
        script: dscSettings.vmSQLScript
        function: dscSettings.vmSQLFunction
      }
      configurationArguments: {
        DNSServerIP: networkSettings.dcPrivateIPAddress
        DomainFQDN: domainFQDN
      }
      privacy: {
        dataCollection: 'enable'
      }
    }
    protectedSettings: {
      configurationArguments: {
        DomainAdminCreds: {
          UserName: adminUserName
          Password: adminPassword
        }
        SqlSvcCreds: {
          UserName: deploymentSettings.sqlSvcUserName
          Password: serviceAccountsPassword
        }
        SPSetupCreds: {
          UserName: deploymentSettings.spSetupUserName
          Password: serviceAccountsPassword
        }
      }
    }
  }
}

// Create resources for VM SP
resource vm_sp_pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (outbound_access_method == 'PublicIPAddress') {
  name: 'vm-sp-pip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${resourceGroupNameFormatted}-${vmsSettings.vmSPName}')
    }
  }
}

resource vm_sp_nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'vm-sp-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId(
              'Microsoft.Network/virtualNetworks/subnets',
              virtual_network.name,
              networkSettings.subnetSPName
            )
          }
          publicIPAddress: ((outbound_access_method == 'PublicIPAddress') ? { id: vm_sp_pip.id } : null)
        }
      }
    ]
  }
}

resource vm_sp_def 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-sp'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSPSize
    }
    osProfile: {
      computerName: vmsSettings.vmSPName
      adminUsername: deploymentSettings.localAdminUserName
      adminPassword: adminPassword
      windowsConfiguration: {
        timeZone: vmsTimeZone
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
        publisher: split(vmsSettings.vmSharePointImage, ':')[0]
        offer: split(vmsSettings.vmSharePointImage, ':')[1]
        sku: split(vmsSettings.vmSharePointImage, ':')[2]
        version: split(vmsSettings.vmSharePointImage, ':')[3]
      }
      osDisk: {
        name: 'vm-sp-disk-os'
        caching: 'ReadWrite'
        osType: 'Windows'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: vmSPStorageAccountType
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm_sp_nic.id
        }
      ]
    }
    licenseType: (enableHybridBenefitServerLicenses ? 'Windows_Server' : null)
  }
}

resource vm_sp_runcommand_setproxy 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = if (outbound_access_method == 'AzureFirewallProxy') {
  parent: vm_sp_def
  name: 'runcommand-setproxy'
  location: location
  properties: {
    source: {
      script: 'param([string]$proxyIp, [string]$proxyHttpPort, [string]$proxyHttpsPort, [string]$localDomainFqdn) $proxy : "http={0}:{1};https={0}:{2}" -f $proxyIp, $proxyHttpPort, $proxyHttpsPort; $bypasslist : "*.{0};<local>" -f $localDomainFqdn; netsh winhttp set proxy proxy-server=$proxy bypass-list=$bypasslist; $proxyEnabled = 1; New-ItemProperty -Path "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" -Name "ProxySettingsPerUser" -PropertyType DWORD -Value 0 -Force; $proxyBytes = [system.Text.Encoding]::ASCII.GetBytes($proxy); $bypassBytes = [system.Text.Encoding]::ASCII.GetBytes($bypasslist); $defaultConnectionSettings = [byte[]]@(@(70, 0, 0, 0, 0, 0, 0, 0, $proxyEnabled, 0, 0, 0, $proxyBytes.Length, 0, 0, 0) + $proxyBytes + @($bypassBytes.Length, 0, 0, 0) + $bypassBytes + @(1..36 | % { 0 })); $registryPaths = @("HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings", "HKLM:\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Internet Settings"); foreach ($registryPath in $registryPaths) { Set-ItemProperty -Path $registryPath -Name ProxyServer -Value $proxy; Set-ItemProperty -Path $registryPath -Name ProxyEnable -Value $proxyEnabled; Set-ItemProperty -Path $registryPath -Name ProxyOverride -Value $bypasslist; Set-ItemProperty -Path "$registryPath\\Connections" -Name DefaultConnectionSettings -Value $defaultConnectionSettings; } Bitsadmin /util /setieproxy localsystem MANUAL_PROXY $proxy $bypasslist;'
    }
    parameters: [
      {
        name: 'proxyIp'
        value: firewall_proxy_settings.azureFirewallIPAddress
      }
      {
        name: 'proxyHttpPort'
        value: firewall_proxy_settings.http_port
      }
      {
        name: 'proxyHttpsPort'
        value: firewall_proxy_settings.https_port
      }
      {
        name: 'proxyIp'
        value: domainFQDN
      }
    ]
    timeoutInSeconds: 90
    treatFailureAsDeploymentFailure: false
  }
}

resource vm_sp_runcommand_increase_dsc_quota 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  parent: vm_sp_def
  name: 'runcommand-increase-dsc-quota'
  location: location
  properties: {
    source: {
      script: 'Set-Item -Path WSMan:\\localhost\\MaxEnvelopeSizeKb -Value 2048'
    }
    timeoutInSeconds: 90
    treatFailureAsDeploymentFailure: false
  }
}

resource vm_sp_ext_applydsc 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm_sp_def
  name: 'apply-dsc'
  location: location
  dependsOn: [
    vm_sp_runcommand_setproxy
    vm_sp_runcommand_increase_dsc_quota
  ]
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.9'
    autoUpgradeMinorVersion: true
    forceUpdateTag: dscSettings.forceUpdateTag
    settings: {
      wmfVersion: 'latest'
      configuration: {
        url: dscSettings.vmSPScriptFileUri
        script: dscSettings.vmSPScript
        function: dscSettings.vmSPFunction
      }
      configurationArguments: {
        DNSServerIP: networkSettings.dcPrivateIPAddress
        DomainFQDN: domainFQDN
        DCServerName: vmsSettings.vmDCName
        SQLServerName: vmsSettings.vmSQLName
        SQLAlias: deploymentSettings.sqlAlias
        SharePointVersion: sharePointVersion
        SharePointSitesAuthority: deploymentSettings.sharePointSitesAuthority
        SharePointCentralAdminPort: deploymentSettings.sharePointCentralAdminPort
        EnableAnalysis: deploymentSettings.enableAnalysis
        SharePointBits: deploymentSettings.sharePointBitsSelected
      }
      privacy: {
        dataCollection: 'enable'
      }
    }
    protectedSettings: {
      configurationArguments: {
        DomainAdminCreds: {
          UserName: adminUserName
          Password: adminPassword
        }
        SPSetupCreds: {
          UserName: deploymentSettings.spSetupUserName
          Password: serviceAccountsPassword
        }
        SPFarmCreds: {
          UserName: deploymentSettings.spFarmUserName
          Password: serviceAccountsPassword
        }
        SPSvcCreds: {
          UserName: deploymentSettings.spSvcUserName
          Password: serviceAccountsPassword
        }
        SPAppPoolCreds: {
          UserName: deploymentSettings.spAppPoolUserName
          Password: serviceAccountsPassword
        }
        SPADDirSyncCreds: {
          UserName: deploymentSettings.spADDirSyncUserName
          Password: serviceAccountsPassword
        }
        SPPassphraseCreds: {
          UserName: 'Passphrase'
          Password: serviceAccountsPassword
        }
        SPSuperUserCreds: {
          UserName: deploymentSettings.spSuperUserName
          Password: serviceAccountsPassword
        }
        SPSuperReaderCreds: {
          UserName: deploymentSettings.spSuperReaderName
          Password: serviceAccountsPassword
        }
      }
    }
  }
}

// Create resources for VMs FEs
resource vm_fe_pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = [
  for i in range(0, numberOfAdditionalFrontEnd): if (numberOfAdditionalFrontEnd >= 1 && outbound_access_method == 'PublicIPAddress') {
    name: 'vm-fe${i}-pip'
    location: location
    sku: {
      name: 'Basic'
      tier: 'Regional'
    }
    properties: {
      publicIPAllocationMethod: 'Static'
      dnsSettings: {
        domainNameLabel: '${toLower('${resourceGroupNameFormatted}-${vmsSettings.vmFEName}')}-${i}'
      }
    }
  }
]

resource vm_fe_nic 'Microsoft.Network/networkInterfaces@2023-11-01' = [
  for i in range(0, numberOfAdditionalFrontEnd): if (numberOfAdditionalFrontEnd >= 1) {
    name: 'vm-fe${i}-nic'
    location: location
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            privateIPAllocationMethod: 'Dynamic'
            subnet: {
              id: resourceId(
                'Microsoft.Network/virtualNetworks/subnets',
                virtual_network.name,
                networkSettings.subnetSPName
              )
            }
            publicIPAddress: (outbound_access_method == 'PublicIPAddress' ? json('{"id": "${vm_fe_pip[i].id}"}') : null)
          }
        }
      ]
    }
    dependsOn: [
      vm_fe_pip[i]
    ]
  }
]

resource vm_fe_def 'Microsoft.Compute/virtualMachines@2024-07-01' = [
  for i in range(0, numberOfAdditionalFrontEnd): if (numberOfAdditionalFrontEnd >= 1) {
    name: 'vm-fe${i}'
    location: location
    dependsOn: [
      vm_fe_nic[i]
    ]
    properties: {
      hardwareProfile: {
        vmSize: vmSPSize
      }
      osProfile: {
        computerName: '${vmsSettings.vmFEName}-${i}'
        adminUsername: deploymentSettings.localAdminUserName
        adminPassword: adminPassword
        windowsConfiguration: {
          timeZone: vmsTimeZone
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
          publisher: split(vmsSettings.vmSharePointImage, ':')[0]
          offer: split(vmsSettings.vmSharePointImage, ':')[1]
          sku: split(vmsSettings.vmSharePointImage, ':')[2]
          version: split(vmsSettings.vmSharePointImage, ':')[3]
        }
        osDisk: {
          name: 'vm-fe${i}-disk-os'
          caching: 'ReadWrite'
          osType: 'Windows'
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: vmSPStorageAccountType
          }
        }
      }
      networkProfile: {
        networkInterfaces: [
          {
            id: vm_fe_nic[i].id
          }
        ]
      }
      licenseType: (enableHybridBenefitServerLicenses ? 'Windows_Server' : null)
    }
  }
]

resource vm_fe_runcommand_setproxy 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = [
  for i in range(0, numberOfAdditionalFrontEnd): if (numberOfAdditionalFrontEnd >= 1 && outbound_access_method == 'AzureFirewallProxy') {
    parent: vm_fe_def[i]
    name: 'runcommand-setproxy'
    location: location
    properties: {
      source: {
        script: 'param([string]$proxyIp, [string]$proxyHttpPort, [string]$proxyHttpsPort, [string]$localDomainFqdn) $proxy : "http={0}:{1};https={0}:{2}" -f $proxyIp, $proxyHttpPort, $proxyHttpsPort; $bypasslist : "*.{0};<local>" -f $localDomainFqdn; netsh winhttp set proxy proxy-server=$proxy bypass-list=$bypasslist; $proxyEnabled = 1; New-ItemProperty -Path "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" -Name "ProxySettingsPerUser" -PropertyType DWORD -Value 0 -Force; $proxyBytes = [system.Text.Encoding]::ASCII.GetBytes($proxy); $bypassBytes = [system.Text.Encoding]::ASCII.GetBytes($bypasslist); $defaultConnectionSettings = [byte[]]@(@(70, 0, 0, 0, 0, 0, 0, 0, $proxyEnabled, 0, 0, 0, $proxyBytes.Length, 0, 0, 0) + $proxyBytes + @($bypassBytes.Length, 0, 0, 0) + $bypassBytes + @(1..36 | % { 0 })); $registryPaths = @("HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings", "HKLM:\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Internet Settings"); foreach ($registryPath in $registryPaths) { Set-ItemProperty -Path $registryPath -Name ProxyServer -Value $proxy; Set-ItemProperty -Path $registryPath -Name ProxyEnable -Value $proxyEnabled; Set-ItemProperty -Path $registryPath -Name ProxyOverride -Value $bypasslist; Set-ItemProperty -Path "$registryPath\\Connections" -Name DefaultConnectionSettings -Value $defaultConnectionSettings; } Bitsadmin /util /setieproxy localsystem MANUAL_PROXY $proxy $bypasslist;'
      }
      parameters: [
        {
          name: 'proxyIp'
          value: firewall_proxy_settings.azureFirewallIPAddress
        }
        {
          name: 'proxyHttpPort'
          value: firewall_proxy_settings.http_port
        }
        {
          name: 'proxyHttpsPort'
          value: firewall_proxy_settings.https_port
        }
        {
          name: 'proxyIp'
          value: domainFQDN
        }
      ]
      timeoutInSeconds: 90
      treatFailureAsDeploymentFailure: false
    }
  }
]

resource vm_fe_ext_applydsc 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = [
  for i in range(0, numberOfAdditionalFrontEnd): if (numberOfAdditionalFrontEnd >= 1) {
    parent: vm_fe_def[i]
    name: 'apply-dsc'
    location: location
    dependsOn: [
      vm_fe_runcommand_setproxy[i]
    ]
    properties: {
      publisher: 'Microsoft.Powershell'
      type: 'DSC'
      typeHandlerVersion: '2.9'
      autoUpgradeMinorVersion: true
      forceUpdateTag: dscSettings.forceUpdateTag
      settings: {
        wmfVersion: 'latest'
        configuration: {
          url: dscSettings.vmFEScriptFileUri
          script: dscSettings.vmFEScript
          function: dscSettings.vmFEFunction
        }
        configurationArguments: {
          DNSServerIP: networkSettings.dcPrivateIPAddress
          DomainFQDN: domainFQDN
          DCServerName: vmsSettings.vmDCName
          SQLServerName: vmsSettings.vmSQLName
          SQLAlias: deploymentSettings.sqlAlias
          SharePointVersion: sharePointVersion
          SharePointSitesAuthority: deploymentSettings.sharePointSitesAuthority
          EnableAnalysis: deploymentSettings.enableAnalysis
          SharePointBits: deploymentSettings.sharePointBitsSelected
        }
        privacy: {
          dataCollection: 'enable'
        }
      }
      protectedSettings: {
        configurationArguments: {
          DomainAdminCreds: {
            UserName: adminUserName
            Password: adminPassword
          }
          SPSetupCreds: {
            UserName: deploymentSettings.spSetupUserName
            Password: serviceAccountsPassword
          }
          SPFarmCreds: {
            UserName: deploymentSettings.spFarmUserName
            Password: serviceAccountsPassword
          }
          SPPassphraseCreds: {
            UserName: 'Passphrase'
            Password: serviceAccountsPassword
          }
        }
      }
    }
  }
]

output publicIPAddressDC string = outbound_access_method == 'PublicIPAddress'
  ? vm_dc_pip.properties.dnsSettings.fqdn
  : ''

output publicIPAddressSQL string = outbound_access_method == 'PublicIPAddress'
  ? vm_sql_pip.properties.dnsSettings.fqdn
  : ''

output publicIPAddressSP string = outbound_access_method == 'PublicIPAddress'
  ? vm_sp_pip.properties.dnsSettings.fqdn
  : ''

output vm_fe_public_dns array = [
  for i in range(0, numberOfAdditionalFrontEnd): vm_fe_pip[i].properties.dnsSettings.fqdn
]
