targetScope = 'resourceGroup'

@description('Azure region.')
param location string

@description('Tags applied to Function resources.')
param tags object

@description('Operational environment name.')
param environmentName string

@description('Function App name.')
param functionAppName string

@description('Basic App Service hosting plan name for the prototype Function App.')
param hostingPlanName string

@description('Storage account used by the Function host runtime.')
@minLength(3)
@maxLength(24)
param functionHostStorageAccountName string

@description('App Service Plan SKU name.')
param functionPlanSkuName string = 'B1'

@description('App Service Plan SKU tier.')
param functionPlanSkuTier string = 'Basic'

@description('App Service Plan SKU size.')
param functionPlanSkuSize string = 'B1'

@description('App Service Plan instance count.')
param functionPlanCapacity int = 1

resource functionStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: functionHostStorageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: hostingPlanName
  location: location
  tags: tags
  kind: 'app'
  sku: {
    name: functionPlanSkuName
    tier: functionPlanSkuTier
    size: functionPlanSkuSize
    capacity: functionPlanCapacity
  }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp'
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${functionStorage.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~20'
        }
        {
          name: 'PRICING_MLOPS_ENVIRONMENT'
          value: environmentName
        }
        {
          name: 'PRICING_MLOPS_HELLO_MESSAGE'
          value: 'hello world'
        }
      ]
    }
  }
}

output functionAppName string = functionApp.name
output functionHostStorageAccountName string = functionStorage.name
