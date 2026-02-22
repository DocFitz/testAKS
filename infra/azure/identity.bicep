// filepath: infra/azure/identity.bicep
param location string
param identityName string

param aksOidcIssuerUrl string
param namespace string
param serviceAccountName string

@description('Name of the Velero storage account (in the SAME RG as this module deployment)')
param storageAccountName string

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

resource fic 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  name: '${uami.name}/velero-fic'
  properties: {
    issuer: aksOidcIssuerUrl
    subject: 'system:serviceaccount:${namespace}:${serviceAccountName}'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

// Existing storage account in CURRENT resource group (module scope)
resource stg 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

var storageBlobDataContributorRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
)

resource raBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(stg.id, uami.name, storageBlobDataContributorRoleId)
  scope: stg
  properties: {
    principalId: uami.properties.principalId
    roleDefinitionId: storageBlobDataContributorRoleId
    principalType: 'ServicePrincipal'
  }
}

output clientId string = uami.properties.clientId
output principalId string = uami.properties.principalId
output identityId string = uami.id
