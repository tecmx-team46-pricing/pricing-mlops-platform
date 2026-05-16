targetScope = 'subscription'

@description('Azure region.')
param location string = 'eastus2'

@description('Project name used for tags and resource names.')
@minLength(3)
param projectName string = 'pricing-mlops'

@description('Operational environment.')
@allowed([
  'staging'
  'sandbox-local'
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

@description('Owner tag for shared infrastructure. Kept here so parameter files can be shared with foundation.')
#disable-next-line no-unused-params
param sharedOwner string = 'team46'

@description('Storage containers used by the MLOps flow.')
param storageContainers array = [
  'input'
  'raw-masked'
  'curated'
  'baseline'
  'runs'
  'snapshots'
  'drift-logs'
  'reports'
  'artifacts'
]

@description('Deploy the hello world Function App for the Pricing MLOps workload.')
param enableHelloFunction bool = true

@description('App Service Plan SKU name for the hello Function App. Default is Basic B1 because Consumption and Free quotas may be unavailable in student subscriptions.')
param functionPlanSkuName string = 'B1'

@description('App Service Plan SKU tier for the hello Function App.')
param functionPlanSkuTier string = 'Basic'

@description('App Service Plan SKU size for the hello Function App.')
param functionPlanSkuSize string = 'B1'

@description('App Service Plan instance count for the hello Function App.')
param functionPlanCapacity int = 1

@description('GitHub repository in org/repo format. Empty value skips workload role assignments.')
param githubRepository string = ''

@description('GitHub environment used by deployments.')
#disable-next-line no-unused-params
param githubEnvironment string = environmentName

@description('Use the GitHub Actions OIDC identity created by foundation.')
param enableGithubActionsIdentity bool = !empty(githubRepository)

@description('Functional model GitHub repository in org/repo format. Empty value skips model repo workload role assignments.')
param modelGithubRepository string = ''

@description('GitHub environment used by the functional model repo.')
#disable-next-line no-unused-params
param modelGithubEnvironment string = githubEnvironment

@description('Use the separate GitHub Actions OIDC identity created for the functional model repo.')
param enableModelGithubActionsIdentity bool = !empty(modelGithubRepository)

@description('Monthly budget amount in subscription currency. Kept here so parameter files can be shared with foundation.')
#disable-next-line no-unused-params
param monthlyBudgetAmount int = 25

@description('Budget notification email list. Kept here so parameter files can be shared with foundation.')
#disable-next-line no-unused-params
param budgetContactEmails array = []

@description('Budget start date. Kept here so parameter files can be shared with foundation.')
#disable-next-line no-unused-params
param budgetStartDate string = utcNow('yyyy-MM-01T00:00:00Z')

var sharedResourceGroupName = 'rg-${projectName}-platform-shared'
var workloadUniqueSuffix = uniqueString(subscription().id, workloadResourceGroupName)
var shortSuffix = take(workloadUniqueSuffix, 6)

var storageAccountName = take('stpmlops${workloadUniqueSuffix}', 24)
var functionHostStorageAccountName = take('stfn${workloadUniqueSuffix}', 24)
var hostingPlanName = 'asp-${projectName}-${environmentName}'
var functionAppName = take('func-${projectName}-${replace(environmentName, 'sandbox-', 'sbx-')}-${shortSuffix}', 60)
var githubActionsIdentityName = 'id-gha-${projectName}-${environmentName}'
var modelGithubActionsIdentityName = 'id-gha-${projectName}-model-${environmentName}'
var dataRoot = 'https://${storageAccountName}.dfs.${environment().suffixes.storage}'
var containerNames = {
  rawMasked: 'raw-masked'
  input: 'input'
  curated: 'curated'
  baseline: 'baseline'
  runs: 'runs'
  snapshots: 'snapshots'
  driftLogs: 'drift-logs'
  reports: 'reports'
  artifacts: 'artifacts'
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

resource githubActionsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = if (enableGithubActionsIdentity) {
  scope: resourceGroup(sharedResourceGroupName)
  name: githubActionsIdentityName
}

resource modelGithubActionsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = if (enableModelGithubActionsIdentity) {
  scope: resourceGroup(sharedResourceGroupName)
  name: modelGithubActionsIdentityName
}

module storage 'modules/storage.bicep' = {
  name: 'pricing-mlops-storage-${uniqueString(workloadResourceGroupName)}'
  scope: resourceGroup(workloadResourceGroupName)
  params: {
    location: location
    tags: workloadTags
    storageAccountName: storageAccountName
    storageContainers: storageContainers
    githubActionsPrincipalId: enableGithubActionsIdentity ? githubActionsIdentity!.properties.principalId : ''
    githubActionsIdentityName: githubActionsIdentityName
    enableGithubActionsIdentity: enableGithubActionsIdentity
    modelGithubActionsPrincipalId: enableModelGithubActionsIdentity ? modelGithubActionsIdentity!.properties.principalId : ''
    modelGithubActionsIdentityName: modelGithubActionsIdentityName
    enableModelGithubActionsIdentity: enableModelGithubActionsIdentity
  }
}

module helloFunction 'modules/hello-function.bicep' = if (enableHelloFunction) {
  name: 'pricing-mlops-hello-function-${uniqueString(workloadResourceGroupName)}'
  scope: resourceGroup(workloadResourceGroupName)
  params: {
    location: location
    tags: workloadTags
    environmentName: environmentName
    functionAppName: functionAppName
    hostingPlanName: hostingPlanName
    functionHostStorageAccountName: functionHostStorageAccountName
    functionPlanSkuName: functionPlanSkuName
    functionPlanSkuTier: functionPlanSkuTier
    functionPlanSkuSize: functionPlanSkuSize
    functionPlanCapacity: functionPlanCapacity
  }
}

output workloadResourceGroupName string = workloadResourceGroupName
output storageAccountName string = storage.outputs.storageAccountName
output dataRoot string = dataRoot
output storageDfsEndpoint string = dataRoot
output containerNames object = containerNames
output modelGithubActionsClientId string = enableModelGithubActionsIdentity ? modelGithubActionsIdentity!.properties.clientId : ''
output functionAppName string = enableHelloFunction ? helloFunction!.outputs.functionAppName : ''
output functionHealthEndpoint string = enableHelloFunction ? 'https://${helloFunction!.outputs.functionAppName}.azurewebsites.net/api/health' : ''
output functionHostStorageAccountName string = enableHelloFunction ? helloFunction!.outputs.functionHostStorageAccountName : ''
