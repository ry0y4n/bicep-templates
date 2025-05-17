targetScope = 'subscription'

@description('The name of the environment')
@minLength(1)
@maxLength(64)
param environmentName string

@description('The location for the resources')
@minLength(1)
param location string

@description('The token that ensures resource names are as unique as possible')
param resourceToken string = toLower(uniqueString(subscription().id, environmentName, location))

param resourceGroupName string = ''
param publisherEmail string = ''
param publisherName string = ''

var abbrs = loadJsonContent('../abbreviations.json')
var tags = { 'env-name': environmentName}

resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'virtualNetworkDeployment'
  scope: targetResourceGroup
  params: {
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    name: '${abbrs.virtualNetworks}${resourceToken}'
    location: location
    subnets: [
      {
        addressPrefix: '10.0.0.0/24'
        name: '${abbrs.networkVirtualNetworksSubnets}pe'
      }
      {
        addressPrefix: '10.0.1.0/24'
        name: '${abbrs.networkVirtualNetworksSubnets}apim-integration'
      }
    ]
  }
}

module apiManagement 'br/public:avm/res/api-management/service:0.9.1' = {
  name: 'apiManagementDeployment'
  scope: targetResourceGroup
  params: {
    name: '${abbrs.apiManagementService}${resourceToken}'
    publisherEmail: publisherEmail
    publisherName: publisherName
    sku: 'StandardV2'
    subnetResourceId: virtualNetwork.outputs.subnetResourceIds[1]
  }
}
