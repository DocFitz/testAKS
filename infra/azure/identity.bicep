// filepath: infra/azure/identity.bicep
param location string
param identityName string

param aksOidcIssuerUrl string
param namespace string
param serviceAccountName string

param storageAccountId string

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

// Storage Blob Data Contributor role
var storageBlobDataContributorRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
)

resource raBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, uami.properties.principalId, storageBlobDataContributorRoleId)
  scope: storageAccountId
  properties: {
    principalId: uami.properties.principalId
    roleDefinitionId: storageBlobDataContributorRoleId
    principalType: 'ServicePrincipal'
  }
}

output clientId string = uami.properties.clientId
output principalId string = uami.properties.principalId
output identityId string = uami.id
