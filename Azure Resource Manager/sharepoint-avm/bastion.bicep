@description('Optional. The location to deploy to.')
param location string = resourceGroup().location

param virtualNetworkName string

param addressPrefix string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  scope: resourceGroup()
  name: virtualNetworkName
}

resource bastion_subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: virtualNetwork
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: addressPrefix //'10.1.2.0/26'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

module bastionHost 'br/public:avm/res/network/bastion-host:0.6.1' = {
  dependsOn: [
    bastion_subnet
  ]
  scope: resourceGroup()
  name: 'bastion'
  params: {
    name: 'bastion'
    virtualNetworkResourceId: virtualNetwork.id
    location: location
    skuName: 'Basic'
    scaleUnits: 2
    disableCopyPaste: false
    publicIPAddressObject: {
      allocationMethod: 'Static'
      name: 'bastion-pip'
      skuName: 'Standard'
      skuTier: 'Regional'
    }
  }
}
