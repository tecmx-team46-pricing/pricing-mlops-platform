using '../foundation/main.bicep'

param location = 'eastus2'
param projectName = 'pricing-mlops'
param environmentName = 'sandbox-local'
param owner = 'local'
param costCenter = 'academic'
param workloadResourceGroupName = 'rg-pricing-mlops-sbx-local'
param workloadLifecycle = 'temporary'
param workloadPurpose = 'personal-sandbox'
param workloadEnvironmentTag = 'sandbox'
param sharedOwner = 'team46'

// Personal sandbox: local/admin only. GitHub Actions OIDC is disabled by default.
param githubRepository = ''
param githubEnvironment = 'sandbox-local'
param enableGithubActionsIdentity = false
param modelGithubRepository = ''
param modelGithubEnvironment = 'sandbox-local'
param enableModelGithubActionsIdentity = false
param enableHelloFunction = true

param storageContainers = [
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

// Personal sandboxes should stay cheap and temporary.
param monthlyBudgetAmount = 0
param budgetContactEmails = []

param extraTags = {
  data_classification: 'masked-or-synthetic'
  maturity: 'prototype'
  subscription_strategy: 'single-subscription'
  subscription_name: '<azure-subscription-name>'
  credit_limit_usd: '200'
}
