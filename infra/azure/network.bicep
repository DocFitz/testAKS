// filepath: infra/azure/network.bicep
param location string
param vnetName string
param vnetCidr string

param aksSubnetName string
param aksSubnetCidr string

param privateEndpointSubnetName string
param privateEndpointSubnetCidr string

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidr
      ]
    }
    subnets: [
      {
        name: aksSubnetName
        properties: {
          addressPrefix: aksSubnetCidr
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetCidr
          // Required for private endpoints in this subnet
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: '${vnet.name}/${aksSubnetName}'
}

resource peSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: '${vnet.name}/${privateEndpointSubnetName}'
}

output vnetId string = vnet.id
output aksSubnetId string = aksSubnet.id
output privateEndpointSubnetId string = peSubnet.id
