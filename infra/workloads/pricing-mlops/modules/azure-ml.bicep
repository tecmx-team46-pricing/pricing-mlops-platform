@description('Azure region.')
param location string

@description('Tags applied to Azure ML resources.')
param tags object

@description('Azure Machine Learning workspace name.')
param azureMlWorkspaceName string

@description('Application Insights component name used by Azure ML.')
param applicationInsightsName string

@description('User-assigned identity resource id used by Azure ML serverless jobs.')
param azureMlJobIdentityId string

@description('User-assigned identity name used by Azure ML serverless jobs.')
param azureMlJobIdentityName string

@description('User-assigned identity principal id used by Azure ML serverless jobs.')
param azureMlJobIdentityPrincipalId string

@description('User-assigned identity client id used by Azure ML serverless jobs.')
param azureMlJobIdentityClientId string

@description('Existing Azure ML associated Container Registry name. Empty value leaves the property unset for first workspace creation.')
param azureMlContainerRegistryName string = ''

@description('Existing workload Storage Account name.')
param storageAccountName string

@description('Shared platform Key Vault resource group name.')
param keyVaultResourceGroupName string

@description('Shared platform Key Vault name.')
param keyVaultName string

@description('Shared Log Analytics workspace resource group name.')
param logAnalyticsResourceGroupName string

@description('Shared Log Analytics workspace name.')
param logAnalyticsWorkspaceName string

@description('Functional model repo GitHub Actions principal id. Used to submit Azure ML jobs.')
param modelGithubActionsPrincipalId string = ''

@description('Create model repo GitHub Actions permissions for Azure ML job submission.')
param enableModelGithubActionsIdentity bool = false

var azureMlDataScientistRoleDefinitionId = 'f6c7c914-8db3-469d-8ca1-694a8f32e121'
var storageBlobDataContributorRoleDefinitionId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var managedIdentityOperatorRoleDefinitionId = 'f1a07417-d97a-45cb-824c-7a7467783830'
var acrPullRoleDefinitionId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource workloadStorage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  scope: resourceGroup(keyVaultResourceGroupName)
  name: keyVaultName
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  scope: resourceGroup(logAnalyticsResourceGroupName)
  name: logAnalyticsWorkspaceName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource azureMlContainerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = if (!empty(azureMlContainerRegistryName)) {
  name: azureMlContainerRegistryName
}

resource azureMlJobIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: azureMlJobIdentityName
}

resource workspace 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: azureMlWorkspaceName
  location: location
  tags: tags
  dependsOn: [
    azureMlJobStorageContributor
  ]
  identity: {
    type: 'SystemAssigned,UserAssigned'
    userAssignedIdentities: {
      '${azureMlJobIdentityId}': {}
    }
  }
  properties: union({
    friendlyName: azureMlWorkspaceName
    storageAccount: workloadStorage.id
    keyVault: keyVault.id
    applicationInsights: appInsights.id
    primaryUserAssignedIdentity: azureMlJobIdentityId
    systemDatastoresAuthMode: 'identity'
    publicNetworkAccess: 'Enabled'
  }, !empty(azureMlContainerRegistryName) ? {
    containerRegistry: azureMlContainerRegistry.id
  } : {})
}

resource azureMlJobStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workloadStorage.id, azureMlJobIdentityId, storageBlobDataContributorRoleDefinitionId)
  scope: workloadStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleDefinitionId)
    principalId: azureMlJobIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource azureMlWorkspaceAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(azureMlContainerRegistryName)) {
  name: guid(azureMlContainerRegistry.id, workspace.id, acrPullRoleDefinitionId)
  scope: azureMlContainerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleDefinitionId)
    principalId: workspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource azureMlJobAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(azureMlContainerRegistryName)) {
  name: guid(azureMlContainerRegistry.id, azureMlJobIdentityId, acrPullRoleDefinitionId)
  scope: azureMlContainerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleDefinitionId)
    principalId: azureMlJobIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource modelGithubAzureMlDataScientist 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableModelGithubActionsIdentity && !empty(modelGithubActionsPrincipalId)) {
  name: guid(workspace.id, modelGithubActionsPrincipalId, azureMlDataScientistRoleDefinitionId)
  scope: workspace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', azureMlDataScientistRoleDefinitionId)
    principalId: modelGithubActionsPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource modelGithubManagedIdentityOperator 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableModelGithubActionsIdentity && !empty(modelGithubActionsPrincipalId)) {
  name: guid(azureMlJobIdentityId, modelGithubActionsPrincipalId, managedIdentityOperatorRoleDefinitionId)
  scope: azureMlJobIdentity
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', managedIdentityOperatorRoleDefinitionId)
    principalId: modelGithubActionsPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output azureMlWorkspaceName string = workspace.name
output azureMlWorkspaceId string = workspace.id
output azureMlWorkspacePrincipalId string = workspace.identity.principalId
output applicationInsightsName string = appInsights.name
output azureMlJobIdentityClientId string = azureMlJobIdentityClientId
