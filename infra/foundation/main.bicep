targetScope = 'subscription'

@description('Azure region.')
param location string = 'eastus2'

@description('Project name used for tags and resource names.')
@minLength(3)
param projectName string = 'pricing-mlops'

@description('Operational environment. Shared is a platform scope, not an MLOps environment.')
@allowed([
  'staging'
  'sandbox-david'
  'validation'
  'data-lab'
])
param environmentName string = 'staging'

@description('Technical owner or team for the workload environment.')
param owner string = 'team46'

@description('Cost center, class, sponsor, or accounting reference.')
param costCenter string = 'academic'

@description('Extra tags applied to workload resources.')
param extraTags object = {}

@description('Resource group for the operational workload environment.')
param workloadResourceGroupName string = 'rg-${projectName}-${environmentName}'

@description('Lifecycle tag for the workload environment.')
@allowed([
  'permanent'
  'temporary'
  'controlled'
])
param workloadLifecycle string = 'permanent'

@description('Purpose tag for the workload environment.')
param workloadPurpose string = 'mlops-staging'

@description('Environment tag for the workload Resource Group. Personal sandboxes use environment=sandbox.')
param workloadEnvironmentTag string = environmentName

@description('Owner tag for shared infrastructure. Keep stable across environment deployments.')
param sharedOwner string = 'team46'

@description('Storage containers used by the MLOps flow. Kept here so the shared parameter files can validate against both entrypoints.')
#disable-next-line no-unused-params
param storageContainers array = [
  'input'
  'baseline'
  'runs'
  'snapshots'
  'drift-logs'
  'reports'
  'artifacts'
]

@description('Deploy the hello world Function App from the workload entrypoint. Kept here so parameter files can be shared.')
#disable-next-line no-unused-params
param enableHelloFunction bool = true

@description('GitHub repository in org/repo format. Empty value skips federated credential creation.')
param githubRepository string = ''

@description('GitHub environment used by deployments.')
param githubEnvironment string = environmentName

@description('Create GitHub Actions OIDC identity and base role assignments for this environment.')
param enableGithubActionsIdentity bool = !empty(githubRepository)

@description('Monthly budget amount in subscription currency. Set 0 to skip budget creation.')
param monthlyBudgetAmount int = 25

@description('Budget notification email list. Empty list skips budget creation.')
param budgetContactEmails array = []

@description('Budget start date. Azure expects yyyy-MM-ddT00:00:00Z.')
param budgetStartDate string = utcNow('yyyy-MM-01T00:00:00Z')

var sharedResourceGroupName = 'rg-${projectName}-platform-shared'
var keyVaultName = take('kv-pmlops-${uniqueString(subscription().id, sharedResourceGroupName)}', 24)
var logAnalyticsName = 'log-${projectName}-shared'
var githubActionsIdentityName = 'id-gha-${projectName}-${environmentName}'
var contributorRoleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

var sharedTags = {
  project: projectName
  owner: sharedOwner
  cost_center: costCenter
  managed_by: 'bicep'
  workload: 'platform'
  subscription_strategy: 'single-subscription'
  subscription_name: '<azure-subscription-name>'
  credit_limit_usd: '200'
  environment: 'shared'
  purpose: 'shared-services'
  lifecycle: 'permanent'
}

var workloadTags = union({
  project: projectName
  owner: owner
  cost_center: costCenter
  managed_by: 'bicep'
  workload: 'pricing-mlops'
  environment: workloadEnvironmentTag
  purpose: workloadPurpose
  lifecycle: workloadLifecycle
}, extraTags)

var shouldCreateBudget = monthlyBudgetAmount > 0 && length(budgetContactEmails) > 0

module resourceGroups 'modules/resource-groups.bicep' = {
  name: 'resource-groups-${uniqueString(sharedResourceGroupName, workloadResourceGroupName)}'
  params: {
    location: location
    sharedResourceGroupName: sharedResourceGroupName
    workloadResourceGroupName: workloadResourceGroupName
    sharedTags: sharedTags
    workloadTags: workloadTags
  }
}

module sharedServices 'modules/shared-services.bicep' = {
  name: 'shared-services-${uniqueString(sharedResourceGroupName)}'
  scope: resourceGroup(sharedResourceGroupName)
  dependsOn: [
    resourceGroups
  ]
  params: {
    location: location
    tags: sharedTags
    keyVaultName: keyVaultName
  }
}

module observability 'modules/observability.bicep' = {
  name: 'observability-${uniqueString(sharedResourceGroupName)}'
  scope: resourceGroup(sharedResourceGroupName)
  dependsOn: [
    resourceGroups
  ]
  params: {
    location: location
    tags: sharedTags
    logAnalyticsName: logAnalyticsName
  }
}

module identities 'modules/identities.bicep' = {
  name: 'identities-${uniqueString(githubActionsIdentityName)}'
  scope: resourceGroup(sharedResourceGroupName)
  dependsOn: [
    resourceGroups
  ]
  params: {
    location: location
    tags: sharedTags
    keyVaultName: sharedServices.outputs.keyVaultName
    githubActionsIdentityName: githubActionsIdentityName
    githubRepository: githubRepository
    githubEnvironment: githubEnvironment
    enableGithubActionsIdentity: enableGithubActionsIdentity
  }
}

resource githubSubscriptionContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableGithubActionsIdentity) {
  name: guid(subscription().id, githubActionsIdentityName, contributorRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleDefinitionId)
    principalId: identities.outputs.githubActionsPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource budget 'Microsoft.Consumption/budgets@2023-05-01' = if (shouldCreateBudget) {
  name: 'budget-${projectName}-mvp'
  properties: {
    category: 'Cost'
    amount: monthlyBudgetAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: budgetStartDate
    }
    notifications: {
      actual80: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: budgetContactEmails
      }
      actual100: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        thresholdType: 'Actual'
        contactEmails: budgetContactEmails
      }
    }
  }
}

output sharedResourceGroupName string = resourceGroups.outputs.sharedResourceGroupName
output workloadResourceGroupName string = resourceGroups.outputs.workloadResourceGroupName
output keyVaultName string = sharedServices.outputs.keyVaultName
output logAnalyticsWorkspaceName string = observability.outputs.logAnalyticsWorkspaceName
output githubActionsClientId string = identities.outputs.githubActionsClientId
output githubActionsPrincipalId string = identities.outputs.githubActionsPrincipalId
output githubActionsSubject string = identities.outputs.githubActionsSubject
