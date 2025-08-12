param virtualNetworkName string
@description('Tags to apply on the resources.')
param tags object

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  scope: resourceGroup()
  name: virtualNetworkName
}

module bastionHost 'br/public:avm/res/network/bastion-host:0.6.1' = {
  scope: resourceGroup()
  name: 'bastion-module-avm'
  params: {
    tags: tags
    name: 'bastion'
    virtualNetworkResourceId: virtualNetwork.id
    skuName: 'Developer'
  }
}
