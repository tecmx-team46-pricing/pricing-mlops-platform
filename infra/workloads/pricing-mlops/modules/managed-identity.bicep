@description('Azure region.')
param location string

@description('Tags applied to the managed identity.')
param tags object

@description('Managed identity name.')
param identityName string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

output identityName string = identity.name
output identityId string = identity.id
output principalId string = identity.properties.principalId
output clientId string = identity.properties.clientId
