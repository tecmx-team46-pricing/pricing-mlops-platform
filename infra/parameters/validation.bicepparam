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
// Validation can be enabled for the model repo when the controlled environment is ready.
param modelGithubRepository = 'tecmx-team46-pricing/pricing-mlops'
param modelGithubEnvironment = 'validation'
param enableModelGithubActionsIdentity = false
param enableHelloFunction = false

// Validation is non-production. Keep budget creation explicit.
param monthlyBudgetAmount = 0
param budgetContactEmails = []

param extraTags = {
  data_classification: 'masked-or-synthetic'
  maturity: 'controlled-non-prod'
  subscription_strategy: 'single-subscription'
  subscription_name: '<azure-subscription-name>'
  credit_limit_usd: '200'
}
