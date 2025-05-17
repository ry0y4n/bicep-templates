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

module networkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.1' = {
  scope: targetResourceGroup
  name: 'networkSecurityGroupDeployment'
  params: {
    name: '${abbrs.networkNetworkSecurityGroups}${resourceToken}'
  }
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
        networkSecurityGroupResourceId: networkSecurityGroup.outputs.resourceId
        delegation: 'Microsoft.Web/serverFarms'
      }
    ]
  }
}

module apiManagement 'apim.bicep' = {
  name: 'apiManagementDeployment'
  scope: targetResourceGroup
  params: {
    location: location
    apimName: '${abbrs.apiManagementService}${resourceToken}'
    subnetResourceId: virtualNetwork.outputs.subnetResourceIds[1]
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: 'privateDnsZoneDeployment'
  scope: targetResourceGroup
  params: {
    name: 'privatelink.azure-api.net'
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}

module privateEndpoint 'br/public:avm/res/network/private-endpoint:0.8.0' = {
  name: 'privateEndpointDeployment'
  scope: targetResourceGroup
  params: {
    name: '${abbrs.privateEndpoint}${resourceToken}'
    subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0]
    privateLinkServiceConnections: [
      {
        name: '${abbrs.networkPrivateLinkServices}${resourceToken}'
        properties: {
          groupIds:[
            'Gateway'
          ]
          privateLinkServiceId: apiManagement.outputs.resourceId
        }
      }
    ]
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          privateDnsZoneResourceId: privateDnsZone.outputs.resourceId
        }
      ]
    }
  }
}


