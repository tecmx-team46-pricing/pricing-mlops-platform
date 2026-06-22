using '../foundation/main.bicep'

param location = 'eastus2'
param projectName = 'pricing-mlops'
param environmentName = 'validation'
param owner = 'team46'
param costCenter = 'academic'
param workloadResourceGroupName = 'rg-pricing-mlops-validation'
param workloadLifecycle = 'controlled'
param workloadPurpose = 'controlled-validation'
param workloadEnvironmentTag = 'validation'
param sharedOwner = 'team46'

// Set this after the GitHub repo exists, for example:
// param githubRepository = 'tecmx-team46-pricing/pricing-mlops-platform'
param githubRepository = 'tecmx-team46-pricing/pricing-mlops-platform'
param githubEnvironment = 'validation'
param enableGithubActionsIdentity = true
param modelGithubRepository = 'tecmx-team46-pricing/pricing-mlops'
param modelGithubEnvironment = 'validation'
param enableModelGithubActionsIdentity = true
param enableAzureMl = true
param useAzureMlWorkspaceV2 = true
param azureMlWorkspaceV2Name = ''
param azureMlContainerRegistryName = 'f807aef31d5e4af08b7ec00956f7e623'

// Validation is non-production. Keep budget creation explicit.
param monthlyBudgetAmount = 0
param budgetContactEmails = []

param extraTags = {
  data_classification: 'masked-or-synthetic'
  maturity: 'controlled-non-prod'
  subscription_strategy: 'single-subscription'
  subscription_name: 'Azure subscription 1'
  credit_limit_usd: '200'
}
