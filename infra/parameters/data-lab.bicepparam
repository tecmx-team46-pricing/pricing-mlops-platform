using '../foundation/main.bicep'

param location = 'eastus2'
param projectName = 'pricing-mlops'
param environmentName = 'data-lab'
param owner = 'team46'
param costCenter = 'academic'
param workloadResourceGroupName = 'rg-pricing-mlops-data-lab'
param workloadLifecycle = 'controlled'
param workloadPurpose = 'secure-data-lab'
param workloadEnvironmentTag = 'data-lab'
param sharedOwner = 'team46'

// Data lab is bootstrapped locally/admin first so GitHub Actions does not get
// default data-plane access to raw-unmasked.
param githubRepository = ''
param githubEnvironment = 'data-lab'
param enableGithubActionsIdentity = false

param storageContainers = [
  'raw-unmasked'
  'raw-masked'
  'curated'
  'baseline'
  'runs'
  'snapshots'
  'drift-logs'
  'reports'
  'artifacts'
]

// Data lab is controlled non-prod. Keep budget creation explicit.
param monthlyBudgetAmount = 0
param budgetContactEmails = []

param extraTags = {
  data_classification: 'unmasked-controlled'
  maturity: 'secure-data-lab'
  subscription_strategy: 'single-subscription'
  subscription_name: '<azure-subscription-name>'
  credit_limit_usd: '200'
}
