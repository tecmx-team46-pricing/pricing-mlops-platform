targetScope = 'subscription'

@description('Azure region.')
param location string = 'eastus2'

@description('Project name used for tags and resource names.')
@minLength(3)
param projectName string = 'pricing-mlops'

@description('Operational platform environment. Shared is deployed as common scope, not as an MLOps environment.')
@allowed([
  'staging'
  'sandbox-david'
  'validation'
])
param environmentName string = 'staging'

@description('Technical owner or team.')
param owner string = 'team46'

@description('Cost center, class, sponsor, or accounting reference.')
param costCenter string = 'academic'

@description('Extra tags applied to all resources.')
param extraTags object = {}

@description('Resource group for the operational environment.')
param workloadResourceGroupName string = 'rg-${projectName}-${environmentName}'

@description('Lifecycle tag for the operational environment.')
@allowed([
  'permanent'
  'temporary'
  'controlled'
])
param workloadLifecycle string = 'permanent'

@description('Purpose tag for the operational environment.')
param workloadPurpose string = 'mlops-staging'

@description('Environment tag for the operational Resource Group. Personal sandboxes use environment=sandbox.')
param workloadEnvironmentTag string = environmentName

@description('Owner tag for shared infrastructure. Keep stable across environment deployments.')
param sharedOwner string = 'team46'

@description('Storage containers used by the MLOps flow.')
param storageContainers array = [
  'input'
  'baseline'
  'runs'
  'snapshots'
  'drift-logs'
  'reports'
  'artifacts'
]

@description('GitHub repository in org/repo format. Leave empty until the repo exists.')
param githubRepository string = ''

@description('GitHub environment used by deployments.')
param githubEnvironment string = 'staging'

@description('Create GitHub Actions OIDC identity and workload role assignments for this environment.')
param enableGithubActionsIdentity bool = !empty(githubRepository)

@description('Monthly budget amount in subscription currency. Set 0 to skip budget creation.')
param monthlyBudgetAmount int = 25

@description('Budget notification email list. Empty list skips budget creation.')
param budgetContactEmails array = []

@description('Budget start date. Azure expects yyyy-MM-ddT00:00:00Z.')
param budgetStartDate string = utcNow('yyyy-MM-01T00:00:00Z')

var sharedResourceGroupName = 'rg-${projectName}-platform-shared'
var workloadUniqueSuffix = uniqueString(subscription().id, workloadResourceGroupName)

var storageAccountName = take('stpmlops${workloadUniqueSuffix}', 24)
var keyVaultName = take('kv-pmlops-${uniqueString(subscription().id, sharedResourceGroupName)}', 24)
var logAnalyticsName = 'log-${projectName}-shared'
var githubActionsIdentityName = 'id-gha-${projectName}-${environmentName}'

var sharedBaseTags = union({
  project: projectName
  owner: sharedOwner
  cost_center: costCenter
  managed_by: 'bicep'
  workload: 'platform'
  subscription_strategy: 'single-subscription'
  subscription_name: '<azure-subscription-name>'
  credit_limit_usd: '200'
}, {})

var workloadBaseTags = union({
  project: projectName
  owner: owner
  cost_center: costCenter
  managed_by: 'bicep'
  workload: 'mlops'
}, extraTags)

var sharedTags = union(sharedBaseTags, {
  environment: 'shared'
  purpose: 'shared-services'
  lifecycle: 'permanent'
})

var workloadTags = union(workloadBaseTags, {
  environment: workloadEnvironmentTag
  purpose: workloadPurpose
  lifecycle: workloadLifecycle
})

var shouldCreateBudget = monthlyBudgetAmount > 0 && length(budgetContactEmails) > 0

resource sharedRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: sharedResourceGroupName
  location: location
  tags: sharedTags
}

resource workloadRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: workloadResourceGroupName
  location: location
  tags: workloadTags
}

module shared 'modules/shared.bicep' = {
  name: 'shared-${uniqueString(sharedResourceGroupName)}'
  scope: resourceGroup(sharedResourceGroupName)
  dependsOn: [
    sharedRg
  ]
  params: {
    location: location
    tags: sharedTags
    keyVaultName: keyVaultName
    logAnalyticsName: logAnalyticsName
    githubActionsIdentityName: githubActionsIdentityName
    githubRepository: githubRepository
    githubEnvironment: githubEnvironment
    enableGithubActionsIdentity: enableGithubActionsIdentity
  }
}

module workload 'modules/staging.bicep' = {
  name: 'workload-${uniqueString(workloadResourceGroupName)}'
  scope: resourceGroup(workloadResourceGroupName)
  dependsOn: [
    workloadRg
  ]
  params: {
    location: location
    tags: workloadTags
    storageAccountName: storageAccountName
    storageContainers: storageContainers
    githubActionsPrincipalId: shared.outputs.githubActionsPrincipalId
    githubActionsIdentityName: githubActionsIdentityName
    enableGithubActionsIdentity: enableGithubActionsIdentity
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

output sharedResourceGroupName string = sharedRg.name
output workloadResourceGroupName string = workloadRg.name
output stagingResourceGroupName string = workloadRg.name
output storageAccountName string = workload.outputs.storageAccountName
output keyVaultName string = shared.outputs.keyVaultName
output logAnalyticsWorkspaceName string = shared.outputs.logAnalyticsWorkspaceName
output githubActionsClientId string = shared.outputs.githubActionsClientId
output githubActionsSubject string = shared.outputs.githubActionsSubject
