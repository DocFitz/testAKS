// filepath: infra/azure/storage-velero.bicep
param location string
param storageAccountName string
param containerName string

param enablePrivateEndpoint bool = false
@description('Required if enablePrivateEndpoint=true')
param privateEndpointSubnetId string = ''
@description('Required if enablePrivateEndpoint=true')
param vnetIdForDnsLink string = ''

@description('Storage redundancy: Standard_LRS or Standard_ZRS typically. ZRS availability varies by region.')
param skuName string = 'Standard_LRS'

resource stg 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: { name: skuName }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false

    // If you enable private endpoint later, you’ll likely switch this to Deny.
    networkAcls: {
      defaultAction: enablePrivateEndpoint ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource blobSvc 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: '${stg.name}/default'
  properties: {
    // “Oops” protection
    isVersioningEnabled: true

    deleteRetentionPolicy: {
      enabled: true
      days: 14
    }

    containerDeleteRetentionPolicy: {
      enabled: true
      days: 14
    }
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${stg.name}/default/${containerName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    blobSvc
  ]
}

// --- Private Endpoint + Private DNS (optional) ---
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (enablePrivateEndpoint) {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
}

resource dnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (enablePrivateEndpoint) {
  name: '${privateDnsZone.name}/link-${uniqueString(vnetIdForDnsLink)}'
  properties: {
    virtualNetwork: {
      id: vnetIdForDnsLink
    }
    registrationEnabled: false
  }
}

resource pe 'Microsoft.Network/privateEndpoints@2024-01-01' = if (enablePrivateEndpoint) {
  name: 'pe-${storageAccountName}-blob'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'blob'
        properties: {
          privateLinkServiceId: stg.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource peDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = if (enablePrivateEndpoint) {
  name: '${pe.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    dnsLink
    pe
  ]
}

output storageAccountName string = stg.name
output storageAccountId string = stg.id
output containerName string = containerName
