targetScope = 'resourceGroup'

@description('Azure region.')
param location string

@description('Tags applied to the Azure ML runtime storage account.')
param tags object

@description('Storage account name used for Azure ML runtime and internal artifacts.')
@minLength(3)
@maxLength(24)
param storageAccountName string

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: union(tags, {
    purpose: 'azure-ml-runtime'
    lifecycle: 'permanent'
    data_classification: 'operational-metadata'
  })
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

output storageAccountName string = storage.name
output storageAccountId string = storage.id
