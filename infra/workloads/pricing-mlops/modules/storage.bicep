targetScope = 'resourceGroup'

@description('Azure region.')
param location string

@description('Tags applied to workload resources.')
param tags object

@description('Storage account name. Lowercase letters and numbers only.')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Storage containers used by the MLOps flow.')
param storageContainers array

@description('Principal id of the GitHub Actions managed identity.')
param githubActionsPrincipalId string = ''

@description('Managed identity name. Used to create stable role assignment ids.')
param githubActionsIdentityName string

@description('Create GitHub Actions workload role assignments.')
param enableGithubActionsIdentity bool = true

var storageBlobDataContributorRoleDefinitionId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [for containerName in storageContainers: {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None'
  }
}]

resource githubStorageBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableGithubActionsIdentity) {
  scope: storage
  name: guid(storage.id, githubActionsIdentityName, storageBlobDataContributorRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleDefinitionId)
    principalId: githubActionsPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output storageAccountName string = storage.name
