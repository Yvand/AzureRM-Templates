@description('Optional. The location to deploy to.')
param location string = resourceGroup().location

@description('Required. The name of the Virtual Network to create.')
param virtualNetworkName string

@description('Required. The name of the Virtual Network to create.')
param addressPrefix string = '10.1.0.0/16'

param networkSecurityRules array

resource nsg_subnet_main 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-subnet-main'
  location: location
  properties: {
    securityRules: networkSecurityRules
  }
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.5.4' = {
  scope: resourceGroup()
  name: '${virtualNetworkName}-module-avm'
  params: {
    addressPrefixes: [
      addressPrefix
    ]
    name: virtualNetworkName
    location: location
    subnets: [
      {
        addressPrefix: cidrSubnet(addressPrefix, 24, 1)
        name: 'mainSubnet'
        defaultOutboundAccess: false
        networkSecurityGroupResourceId: nsg_subnet_main.id
      }
    ]
  }
}

@description('The resource ID of the virtual networks.')
// output vnetResourceId string = virtualNetwork.id
output vnetResourceId string = virtualNetwork.outputs.resourceId
@description('The name of the virtual networks.')
// output vnetResourceId string = virtualNetwork.id
output vnetName string = virtualNetwork.outputs.name
@description('The resource ID of the main subnet.')
// output mainSubnetResourceId string = virtualNetwork.properties.subnets[0].id
output mainSubnetResourceId string = virtualNetwork.outputs.subnetResourceIds[0]
