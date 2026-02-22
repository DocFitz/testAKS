// filepath: infra/azure/main.bicep
targetScope = 'subscription'

@allowed([
  'dev'
  'qa'
  'prod'
])
param env string

param location string = 'centralus'

@description('Optional: deploy storage private endpoint + private DNS for blob')
param enablePrivateEndpoint bool = false
//private endpoint for blob storage, may be reccomended.

@description('Address space for the env VNet')
param vnetCidr string = '10.240.0.0/16'

@description('Subnet for AKS nodes')
param aksSubnetCidr string = '10.240.0.0/20'

@description('Subnet for private endpoints')
param privateEndpointSubnetCidr string = '10.240.16.0/24'

@description('AKS cluster name')
param aksName string = 'aks-${env}'

@description('AKS node pool VM size')
param nodeVmSize string = 'Standard_D2ads_v7'

@description('AKS initial node count')
param nodeCount int = 2

@description('Velero namespace + serviceaccount')
param veleroNamespace string = 'velero'
param veleroServiceAccountName string = 'velero-sa'

@description('Velero storage account name prefix (3-11 chars lowercase/numbers). A unique suffix will be added.')
param veleroStoragePrefix string = 'stvelero'

var veleroStorageAccountName = toLower('${veleroStoragePrefix}${env}${substring(uniqueString(subscription().id, env), 0, 8)}')

var rgAks = 'rg-aks-${env}'
var rgNet = 'rg-net-${env}'
var rgBackup = 'rg-backup-${env}'

resource rgAksRes 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: rgAks
  location: location
}

resource rgNetRes 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: rgNet
  location: location
}

resource rgBackupRes 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: rgBackup
  location: location
}

module net './network.bicep' = {
  name: 'net-${env}'
  scope: resourceGroup(rgNet)
  params: {
    location: location
    vnetName: 'vnet-${env}'
    vnetCidr: vnetCidr
    aksSubnetName: 'snet-aks'
    aksSubnetCidr: aksSubnetCidr
    privateEndpointSubnetName: 'snet-private-endpoints'
    privateEndpointSubnetCidr: privateEndpointSubnetCidr
  }
  dependsOn: [
    rgNetRes
  ]
}

module aks './aks.bicep' = {
  name: 'aks-${env}'
  scope: resourceGroup(rgAks)
  params: {
    location: location
    aksName: aksName
    nodeCount: nodeCount
    nodeVmSize: nodeVmSize
    subnetId: net.outputs.aksSubnetId
  }
  dependsOn: [
    rgAksRes
    net
  ]
}

module veleroStorage './storage-velero.bicep' = {
  name: 'velero-storage-${env}'
  scope: resourceGroup(rgBackup)
  params: {
    location: location
    storageAccountName: veleroStorageAccountName
    containerName: 'velero-${env}'
    enablePrivateEndpoint: enablePrivateEndpoint
    privateEndpointSubnetId: net.outputs.privateEndpointSubnetId
    vnetIdForDnsLink: net.outputs.vnetId
  }
}

// filepath: infra/azure/main.bicep
module veleroIdentity './identity.bicep' = {
  name: 'velero-identity-${env}'
  scope: resourceGroup(rgBackup)
  params: {
    location: location
    identityName: 'mi-velero-${env}'
    aksOidcIssuerUrl: aks.outputs.oidcIssuerUrl
    namespace: veleroNamespace
    serviceAccountName: veleroServiceAccountName

    storageAccountName: veleroStorage.outputs.storageAccountName
  }
}

output resourceGroupAks string = rgAks
output resourceGroupNet string = rgNet
output resourceGroupBackup string = rgBackup

output veleroContainerName string = veleroStorage.outputs.containerName
output veleroStorageAccountName string = veleroStorage.outputs.storageAccountName

output veleroManagedIdentityClientId string = veleroIdentity.outputs.clientId
output veleroManagedIdentityResourceId string = veleroIdentity.outputs.identityId
