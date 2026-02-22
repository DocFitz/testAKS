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
  }
}

// Subnet for AKS nodes
resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: '${vnet.name}/${aksSubnetName}'
  properties: {
    addressPrefix: aksSubnetCidr
  }
  dependsOn: [
    vnet
  ]
}

// Subnet for private endpoints
resource peSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: '${vnet.name}/${privateEndpointSubnetName}'
  properties: {
    addressPrefix: privateEndpointSubnetCidr

    // Required so private endpoints can be created in this subnet
    privateEndpointNetworkPolicies: 'Disabled'
  }
  dependsOn: [
    vnet
  ]
}

output vnetId string = vnet.id
output aksSubnetId string = aksSubnet.id
output privateEndpointSubnetId string = peSubnet.id
