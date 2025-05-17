param location string
param apimName string
param subnetResourceId string
param publisherEmail string
param publisherName string

resource apiManagement 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apimName
  location: location
  sku: {
    capacity: 1
    name: 'StandardV2'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkConfiguration: {
      subnetResourceId: subnetResourceId
    }
    virtualNetworkType: 'External'
    publicNetworkAccess: 'Disabled'
  }
}

output resourceId string = apiManagement.id
