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

@description('Workload Storage Account used by the Pricing MLOps flow.')
param workloadStorageAccountName string

@description('Azure ML workspace name used by the Function orchestrator.')
param azureMlWorkspaceName string

@description('Resource group that contains the Azure ML workspace.')
param azureMlWorkspaceResourceGroupName string

@description('Principal id of the functional model repo GitHub Actions managed identity.')
param modelGithubActionsPrincipalId string = ''

@description('Create publish permissions for the model repo GitHub Actions identity.')
param enableModelGithubActionsIdentity bool = false

@description('App Service Plan SKU name.')
param functionPlanSkuName string = 'Y1'

@description('App Service Plan SKU tier.')
param functionPlanSkuTier string = 'Dynamic'

@description('App Service Plan SKU size.')
param functionPlanSkuSize string = 'Y1'

@description('App Service Plan instance count.')
param functionPlanCapacity int = 1

var storageBlobDataContributorRoleDefinitionId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var websiteContributorRoleDefinitionId = 'de139f84-1756-47ae-9be6-808fbbe84772'
var azureMlDataScientistRoleDefinitionId = 'f6c7c914-8db3-469d-8ca1-694a8f32e121'

resource workloadStorage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: workloadStorageAccountName
}

resource azureMlWorkspace 'Microsoft.MachineLearningServices/workspaces@2024-04-01' existing = {
  name: azureMlWorkspaceName
}

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
  kind: 'linux'
  sku: union({
    name: functionPlanSkuName
    tier: functionPlanSkuTier
    size: functionPlanSkuSize
  }, functionPlanSkuTier == 'Dynamic' ? {} : {
    capacity: functionPlanCapacity
  })
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      remoteDebuggingEnabled: false
      detailedErrorLoggingEnabled: false
      linuxFxVersion: 'Python|3.11'
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
          value: 'python'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'true'
        }
        {
          name: 'PRICING_MLOPS_ENVIRONMENT'
          value: environmentName
        }
        {
          name: 'PRICING_MLOPS_HELLO_MESSAGE'
          value: 'hello world'
        }
        {
          name: 'AZURE_SUBSCRIPTION_ID'
          value: subscription().subscriptionId
        }
        {
          name: 'AZURE_RESOURCE_GROUP'
          value: azureMlWorkspaceResourceGroupName
        }
        {
          name: 'AZURE_ML_WORKSPACE'
          value: azureMlWorkspaceName
        }
        {
          name: 'AZURE_STORAGE_ACCOUNT'
          value: workloadStorageAccountName
        }
        {
          name: 'MLOPS_CONTAINER_RAW_MASKED'
          value: 'raw-masked'
        }
        {
          name: 'MLOPS_CONTAINER_CURATED'
          value: 'curated'
        }
        {
          name: 'MLOPS_CONTAINER_RUNS'
          value: 'runs'
        }
        {
          name: 'MLOPS_CONTAINER_SNAPSHOTS'
          value: 'snapshots'
        }
        {
          name: 'MLOPS_CONTAINER_DRIFT_LOGS'
          value: 'drift-logs'
        }
        {
          name: 'MLOPS_CONTAINER_REPORTS'
          value: 'reports'
        }
        {
          name: 'MLOPS_CONTAINER_ARTIFACTS'
          value: 'artifacts'
        }
        {
          name: 'MLOPS_COMPUTE_TARGET'
          value: 'azure-ml'
        }
      ]
    }
  }
}

resource functionStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: workloadStorage
  name: guid(workloadStorage.id, functionApp.name, storageBlobDataContributorRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleDefinitionId)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource functionAzureMlDataScientist 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: azureMlWorkspace
  name: guid(azureMlWorkspace.id, functionApp.name, azureMlDataScientistRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', azureMlDataScientistRoleDefinitionId)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource modelGithubFunctionPublisher 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableModelGithubActionsIdentity && !empty(modelGithubActionsPrincipalId)) {
  scope: functionApp
  name: guid(functionApp.id, modelGithubActionsPrincipalId, websiteContributorRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', websiteContributorRoleDefinitionId)
    principalId: modelGithubActionsPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output functionAppName string = functionApp.name
output functionHostStorageAccountName string = functionStorage.name
