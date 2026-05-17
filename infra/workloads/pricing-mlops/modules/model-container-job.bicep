targetScope = 'resourceGroup'

@description('Azure region.')
param location string

@description('Tags applied to workload resources.')
param tags object

@description('Azure Container Registry name.')
@minLength(5)
@maxLength(50)
param containerRegistryName string

@description('Container Apps managed environment name.')
param managedEnvironmentName string

@description('User-assigned managed identity name for the Azure model job.')
param modelJobIdentityName string

@description('Container Apps Job name for the Pricing MLOps model flow.')
@maxLength(32)
param modelJobName string

@description('Shared Log Analytics resource group name.')
param logAnalyticsResourceGroupName string

@description('Shared Log Analytics workspace name.')
param logAnalyticsWorkspaceName string

@description('Workload Storage Account name.')
param storageAccountName string

@description('Initial container image. GitHub Actions overrides this image when starting a real run.')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Container CPU cores for the model job.')
@allowed([
  '0.25'
  '0.5'
  '0.75'
  '1.0'
  '1.25'
  '1.5'
  '1.75'
  '2.0'
])
param modelJobCpu string = '0.25'

@description('Container memory for the model job.')
@allowed([
  '0.5Gi'
  '1.0Gi'
  '1.5Gi'
  '2.0Gi'
  '2.5Gi'
  '3.0Gi'
  '3.5Gi'
  '4.0Gi'
])
param modelJobMemory string = '0.5Gi'

@description('Principal id of the functional model repo GitHub Actions managed identity.')
param modelGithubActionsPrincipalId string = ''

@description('Create model repo GitHub Actions permissions for ACR push and job start.')
param enableModelGithubActionsIdentity bool = false

var acrPushRoleDefinitionId = '8311e382-0749-4cb8-b61a-304f252e45ec'
var acrPullRoleDefinitionId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var containerAppsJobsOperatorRoleDefinitionId = 'b9a307c4-5aa3-4b52-ba60-2b17c136cd7b'
var storageBlobDataContributorRoleDefinitionId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  scope: resourceGroup(logAnalyticsResourceGroupName)
  name: logAnalyticsWorkspaceName
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
      trustPolicy: {
        status: 'disabled'
        type: 'Notary'
      }
    }
  }
}

resource modelJobIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: modelJobIdentityName
  location: location
  tags: tags
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: managedEnvironmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource modelJobAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: registry
  name: guid(registry.id, modelJobIdentity.name, acrPullRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleDefinitionId)
    principalId: modelJobIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource modelGithubAcrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableModelGithubActionsIdentity && !empty(modelGithubActionsPrincipalId)) {
  scope: registry
  name: guid(registry.id, modelGithubActionsPrincipalId, acrPushRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPushRoleDefinitionId)
    principalId: modelGithubActionsPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource modelJobStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, modelJobIdentity.name, storageBlobDataContributorRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleDefinitionId)
    principalId: modelJobIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource modelJob 'Microsoft.App/jobs@2024-03-01' = {
  name: modelJobName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${modelJobIdentity.id}': {}
    }
  }
  properties: {
    environmentId: managedEnvironment.id
    configuration: {
      triggerType: 'Manual'
      replicaTimeout: 1800
      replicaRetryLimit: 0
      manualTriggerConfig: {
        parallelism: 1
        replicaCompletionCount: 1
      }
      registries: [
        {
          server: registry.properties.loginServer
          identity: modelJobIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'pricing-mlops'
          image: containerImage
          env: [
            {
              name: 'AZURE_STORAGE_ACCOUNT'
              value: storageAccountName
            }
          ]
          resources: {
            cpu: json(modelJobCpu)
            memory: modelJobMemory
          }
        }
      ]
    }
  }
  dependsOn: [
    modelJobAcrPull
    modelJobStorageContributor
  ]
}

resource modelGithubJobOperator 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableModelGithubActionsIdentity && !empty(modelGithubActionsPrincipalId)) {
  scope: modelJob
  name: guid(modelJob.id, modelGithubActionsPrincipalId, containerAppsJobsOperatorRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', containerAppsJobsOperatorRoleDefinitionId)
    principalId: modelGithubActionsPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output containerRegistryName string = registry.name
output containerRegistryLoginServer string = registry.properties.loginServer
output managedEnvironmentName string = managedEnvironment.name
output modelJobIdentityName string = modelJobIdentity.name
output modelJobIdentityClientId string = modelJobIdentity.properties.clientId
output modelJobName string = modelJob.name
